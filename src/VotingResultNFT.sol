// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "node_modules/@openzeppelin/contracts/access/Ownable.sol";

/// @title Контракт NFT для результатов голосования
contract VotingResultNFT is ERC721, Ownable {
    uint256 public nextTokenId;

    struct VotingResult {
        uint256 voteId;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
    }
    
    // Сопоставление токена с результатами голосования
    mapping(uint256 => VotingResult) public results;

    constructor() ERC721("VotingResultNFT", "VRNFT") Ownable(msg.sender) {}

    /// @notice Создает NFT с результатами голосования
    /// @param to Адрес, которому будет выдан NFT
    /// @param _voteId Идентификатор голосования
    /// @param _description Описание или вопрос голосования
    /// @param _yesVotes Суммарная сила голосов "за"
    /// @param _noVotes Суммарная сила голосов "против"
    function mint(
        address to,
        uint256 _voteId,
        string memory _description,
        uint256 _yesVotes,
        uint256 _noVotes
    ) external onlyOwner {
        uint256 tokenId = nextTokenId;
        nextTokenId++;
        _mint(to, tokenId);
        results[tokenId] = VotingResult({
            voteId: _voteId,
            description: _description,
            yesVotes: _yesVotes,
            noVotes: _noVotes
        });
    }
}