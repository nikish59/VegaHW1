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

/// @notice Тестовый контракт для проверки работы VotingContract
contract VotingTest is Test {
    TestToken public token;
    VotingContract public voting;
    VotingResultNFT public nft;
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

    function decimals() internal pure returns(uint8) {
        return 18;
    }

    /// @notice Проверка создания голосования
    function testCreateVote() public {
        voting.createVote("Test Vote", 1 days, 1000);
        (uint256 id, string memory description, uint256 deadline, uint256 threshold, uint256 yesVotes, uint256 noVotes, bool concluded) = voting.getVote(1);
        assertEq(id, 1);
        assertEq(description, "Test Vote");
        assertEq(threshold, 1000);
        assertGt(deadline, block.timestamp);
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertEq(concluded, false);
    }

    /// @notice Проверка голосования "за" с высоким порогом, чтобы голосование не завершалось автоматически
    function testVoteYes() public {
        // Устанавливаем высокий порог, чтобы голосование оставалось незавершённым после первого голоса
        voting.createVote("Vote Yes Test", 1 days, 1e30);
        uint256 voteId = 1;
        uint256 stakeAmount = 10 * 10 ** decimals();
        uint256 stakePeriod = 1 hours;

        vm.prank(voter1);
        token.approve(address(voting), stakeAmount);
        vm.prank(voter1);
        voting.vote(voteId, true, stakeAmount, stakePeriod);

        (, , , , uint256 yesVotes, uint256 noVotes, bool concluded) = voting.getVote(voteId);
        uint256 expectedVotingPower = stakeAmount * (stakePeriod * stakePeriod);
        assertEq(yesVotes, expectedVotingPower);
        assertEq(noVotes, 0);
        // Голосование не должно быть завершено, так как порог не достигнут
        assertTrue(!concluded);
    }

    /// @notice Проверка голосования "против" и повторного голосования для голосования, которое автоматически завершается
    function testVoteNoAndDoubleVoteFail() public {
        // Устанавливаем низкий порог, чтобы голосование автоматически завершалось после первого голоса
        voting.createVote("Vote No Test", 1 days, 50);
        uint256 voteId = 1;
        uint256 stakeAmount = 5 * 10 ** decimals();
        uint256 stakePeriod = 2 hours;

        vm.prank(voter2);
        token.approve(address(voting), stakeAmount);
        vm.prank(voter2);
        voting.vote(voteId, false, stakeAmount, stakePeriod);

        (, , , , , uint256 noVotes,) = voting.getVote(voteId);
        uint256 expectedVotingPower = stakeAmount * (stakePeriod * stakePeriod);
        assertEq(noVotes, expectedVotingPower);

        // Ожидаем, что голосование уже завершено, поэтому повторное голосование вызывает revert с ошибкой "Vote already concluded"
        vm.prank(voter2);
        token.approve(address(voting), stakeAmount);
        vm.prank(voter2);
        vm.expectRevert("Vote already concluded");
        voting.vote(voteId, false, stakeAmount, stakePeriod);
    }

    /// @notice Проверка автоматического завершения голосования при достижении порога
    function testConcludeVoteOnThreshold() public {
        // Создаем голосование с порогом, который будет достигнут одним голосом
        voting.createVote("Threshold Test", 1 days, 50);
        uint256 voteId = 1;
        uint256 stakeAmount = 1 * 10 ** decimals();
        uint256 stakePeriod = 10 hours;

        vm.prank(voter1);
        token.approve(address(voting), stakeAmount);
        vm.prank(voter1);
        voting.vote(voteId, true, stakeAmount, stakePeriod);

        (, , , , , , bool concluded) = voting.getVote(voteId);
        assertTrue(concluded);
    }
}
