// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/VotingResultNFT.sol";
import "../src/VotingContract.sol";

contract Deploy is Script {
    // Адрес уже развернутого токена VegaVote
    address constant TOKEN_ADDRESS = 0xD3835FE9807DAecc7dEBC53795E7170844684CeF;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Развертывание контракта NFT для результатов голосования
        VotingResultNFT nft = new VotingResultNFT();

        // Развертывание контракта голосования с использованием уже существующего токена
        VotingContract voting = new VotingContract(IERC20(TOKEN_ADDRESS), IVotingResultNFT(address(nft)));

        // Передаём владение NFT контракту голосования,
        // чтобы он имел право чеканить NFT с результатами голосования
        nft.transferOwnership(address(voting));

        vm.stopBroadcast();
    }
}
