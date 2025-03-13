// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Интерфейс для взаимодействия с контрактом NFT результатов голосования
interface IVotingResultNFT {
    function mint(address to, uint256 _voteId, string memory _description, uint256 _yesVotes, uint256 _noVotes) external;
}

/// @title Контракт голосования с автоматическим созданием NFT результатов
contract VotingContract is Ownable {
    IERC20 public vegaToken;
    IVotingResultNFT public nftContract;
    uint256 public voteCount;
    uint256 public constant MAX_STAKE_PERIOD = 4 * 365 days;

    // Структура голосования
    struct Vote {
        uint256 id;
        string description;
        uint256 deadline;
        uint256 threshold;
        uint256 yesVotes;
        uint256 noVotes;
        bool concluded;
        mapping(address => bool) hasVoted;
    }
    
    mapping(uint256 => Vote) internal votes;

    event VoteCreated(uint256 indexed voteId, string description, uint256 deadline, uint256 threshold);
    event Voted(
        uint256 indexed voteId,
        address indexed voter,
        bool voteYes,
        uint256 stakeAmount,
        uint256 stakePeriod,
        uint256 votingPower
    );
    event VoteConcluded(uint256 indexed voteId, uint256 yesVotes, uint256 noVotes);

    /// @param _vegaToken Адрес токена VegaVote (ERC20)
    /// @param _nftContract Адрес контракта NFT для результатов голосования
    constructor(IERC20 _vegaToken, IVotingResultNFT _nftContract) Ownable(msg.sender) {
        vegaToken = _vegaToken;
        nftContract = _nftContract;
    }
    
    /// @notice Создаёт голосование (только администратор)
    function createVote(string memory _description, uint256 _duration, uint256 _threshold) external onlyOwner {
        require(_duration <= MAX_STAKE_PERIOD, "Duration exceeds maximum allowed period");
        voteCount++;
        Vote storage newVote = votes[voteCount];
        newVote.id = voteCount;
        newVote.description = _description;
        newVote.deadline = block.timestamp + _duration;
        newVote.threshold = _threshold;
        newVote.concluded = false;
        
        emit VoteCreated(voteCount, _description, newVote.deadline, _threshold);
    }
    
    /// @notice Функция голосования с расчетом силы голоса: stakeAmount * (stakePeriod)^2
    function vote(uint256 _voteId, bool _voteYes, uint256 _stakeAmount, uint256 _stakePeriod) external {
        require(_stakePeriod <= MAX_STAKE_PERIOD, "Stake period too long");
        Vote storage currentVote = votes[_voteId];
        require(block.timestamp < currentVote.deadline, "Voting period has ended");
        require(!currentVote.concluded, "Vote already concluded");
        require(!currentVote.hasVoted[msg.sender], "Address has already voted");
        require(vegaToken.transferFrom(msg.sender, address(this), _stakeAmount), "Token transfer failed");

        uint256 votingPower = _stakeAmount * (_stakePeriod * _stakePeriod);
        if (_voteYes) {
            currentVote.yesVotes += votingPower;
        } else {
            currentVote.noVotes += votingPower;
        }
        currentVote.hasVoted[msg.sender] = true;

        emit Voted(_voteId, msg.sender, _voteYes, _stakeAmount, _stakePeriod, votingPower);
        
        // Если порог достигнут, завершаем голосование
        if (currentVote.yesVotes + currentVote.noVotes >= currentVote.threshold) {
            concludeVote(_voteId);
        }
    }
    
    /// @notice Завершает голосование и автоматически создает NFT с результатами
    function concludeVote(uint256 _voteId) public {
        Vote storage currentVote = votes[_voteId];
        require(!currentVote.concluded, "Vote already concluded");
        require(block.timestamp >= currentVote.deadline || (currentVote.yesVotes + currentVote.noVotes >= currentVote.threshold), "Voting not ended yet");
        currentVote.concluded = true;
        emit VoteConcluded(_voteId, currentVote.yesVotes, currentVote.noVotes);
        
        // Автоматическое чеканение NFT. Здесь NFT создается на адрес владельца контракта.
        nftContract.mint(owner(), _voteId, currentVote.description, currentVote.yesVotes, currentVote.noVotes);
    }
    
    /// @notice Получение информации о голосовании
    function getVote(uint256 _voteId) external view returns (
        uint256 id,
        string memory description,
        uint256 deadline,
        uint256 threshold,
        uint256 yesVotes,
        uint256 noVotes,
        bool concluded
    ) {
        Vote storage currentVote = votes[_voteId];
        return (currentVote.id, currentVote.description, currentVote.deadline, currentVote.threshold, currentVote.yesVotes, currentVote.noVotes, currentVote.concluded);
    }
}
