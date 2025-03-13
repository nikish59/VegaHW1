// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/VotingContract.sol";
import "../src/VotingResultNFT.sol";
import "node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Тестовый токен для имитации токена VegaVote
contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TTK") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }
}

/// @notice Тестовый контракт для проверки автоматического создания NFT с результатами голосования
contract VotingNFTTest is Test {
    TestToken public token;
    VotingResultNFT public nft;
    VotingContract public voting;
    address public owner;
    address public voter1;
    address public voter2;

    function setUp() public {
        owner = address(this);
        token = new TestToken();
        nft = new VotingResultNFT();
        
        voting = new VotingContract(IERC20(address(token)), IVotingResultNFT(address(nft)));

        nft.transferOwnership(address(voting));


        voter1 = address(0x1);
        voter2 = address(0x2);

        token.transfer(voter1, 1000 * 10 ** decimals());
        token.transfer(voter2, 1000 * 10 ** decimals());
    }

    function decimals() internal pure returns (uint8) {
        return 18;
    }

    /// @notice Тест: автоматическое создание NFT при достижении порога голосования
    function testNFTMintedOnThreshold() public {
        // Создаём голосование с низким порогом, чтобы один голос завершил его автоматически
        voting.createVote("NFT Test Vote", 1 days, 50);
        uint256 voteId = 1;
       
        uint256 stakeAmount = 1 * 10 ** decimals();
        uint256 stakePeriod = 10 hours;

        // voter1 одобряет перевод токенов и голосует "за"
        vm.prank(voter1);
        token.approve(address(voting), stakeAmount);
        vm.prank(voter1);
        voting.vote(voteId, true, stakeAmount, stakePeriod);

        // После голосования голосование должно быть завершено и NFT создан автоматически
        // Проверяем, что NFT с tokenId 0 существует и его владелец – владелец VotingContract (owner)
        address nftOwner = nft.ownerOf(0);
        assertEq(nftOwner, owner);

        // Проверяем данные, сохранённые в NFT
        (uint256 storedVoteId, string memory description, uint256 yesVotes, uint256 noVotes) = nft.results(0);
        assertEq(storedVoteId, voteId);
        assertEq(description, "NFT Test Vote");
        uint256 expectedVotingPower = stakeAmount * (stakePeriod * stakePeriod);
        // Голос был "за", поэтому yesVotes должно равняться вычисленной силе голоса, а noVotes – 0
        assertEq(yesVotes, expectedVotingPower);
        assertEq(noVotes, 0);
    }

    /// @notice Тест: создание NFT после истечения дедлайна голосования
    function testNFTMintedAfterDeadline() public {
        // Создаём голосование с высоким порогом, чтобы оно не завершилось автоматически голосами
        voting.createVote("NFT Deadline Vote", 1 days, 1e30);
        uint256 voteId = 1;
        uint256 stakeAmount = 1 * 10 ** decimals();
        uint256 stakePeriod = 1 hours;

        vm.prank(voter2);
        token.approve(address(voting), stakeAmount);
        vm.prank(voter2);
        voting.vote(voteId, false, stakeAmount, stakePeriod);

        // Проверяем, что голосование ещё не завершено
        (, , , , , , bool concludedBefore) = voting.getVote(voteId);
        assertTrue(!concludedBefore);

        // Сдвигаем время вперёд, чтобы истёк дедлайн голосования
        vm.warp(block.timestamp + 2 days);

        // Вызываем вручную завершение голосования
        voting.concludeVote(voteId);

        // После завершения голосования NFT должен быть создан
        address nftOwner = nft.ownerOf(0);
        assertEq(nftOwner, owner);

        (uint256 storedVoteId, string memory description, uint256 yesVotes, uint256 noVotes) = nft.results(0);
        assertEq(storedVoteId, voteId);
        assertEq(description, "NFT Deadline Vote");
        uint256 expectedVotingPower = stakeAmount * (stakePeriod * stakePeriod);
        // Голос был "против", поэтому noVotes должно равняться вычисленной силе голоса, а yesVotes – 0
        assertEq(yesVotes, 0);
        assertEq(noVotes, expectedVotingPower);
    }
}
