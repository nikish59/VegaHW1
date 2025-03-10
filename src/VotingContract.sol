// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VotingContract is Ownable {
    IERC20 public vegaToken; // Токен VegaVote (ERC20)
    uint256 public voteCount;
    uint256 public constant MAX_STAKE_PERIOD = 4 * 365 days; // Максимальный период стейкинга (4 года)

    // Структура голосования
    struct Vote {
        uint256 id;
        string description;
        uint256 deadline; // Время окончания голосования
        uint256 threshold; // Порог суммарной силы голосов для завершения голосования
        uint256 yesVotes;
        uint256 noVotes;
        bool concluded;
        mapping(address => bool) hasVoted; // Проверка, голосовал ли адрес
    }

    // Из-за наличия mapping внутри структуры нельзя сделать votes публичными напрямую
    mapping(uint256 => Vote) internal votes;

    // События для логирования действий
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

    constructor(IERC20 _vegaToken) {
        vegaToken = _vegaToken;
    }

    /// @notice Инициализация голосования (только администратор)
    /// @param _description Описание или вопрос голосования
    /// @param _duration Продолжительность голосования (в секундах, не более 4 лет)
    /// @param _threshold Порог суммарной силы голосов для завершения голосования
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

    /// @notice Участник голосует, стейкая токены, где сила голоса = stakeAmount * (stakePeriod)^2
    /// @param _voteId Идентификатор голосования
    /// @param _voteYes true, если голос "за", false - если "против"
    /// @param _stakeAmount Количество токенов для стейкинга
    /// @param _stakePeriod Период стейкинга (в секундах, не более 4 лет)
    function vote(uint256 _voteId, bool _voteYes, uint256 _stakeAmount, uint256 _stakePeriod) external {
        require(_stakePeriod <= MAX_STAKE_PERIOD, "Stake period too long");

        Vote storage currentVote = votes[_voteId];
        require(block.timestamp < currentVote.deadline, "Voting period has ended");
        require(!currentVote.concluded, "Vote already concluded");
        require(!currentVote.hasVoted[msg.sender], "Address has already voted");

        // Перевод токенов от участника в контракт (предварительно должно быть выполнено approve)
        require(vegaToken.transferFrom(msg.sender, address(this), _stakeAmount), "Token transfer failed");

        // Вычисление силы голоса: votingPower = stakeAmount * (stakePeriod)^2
        uint256 votingPower = _stakeAmount * (_stakePeriod * _stakePeriod);

        // Обновление результатов голосования
        if (_voteYes) {
            currentVote.yesVotes += votingPower;
        } else {
            currentVote.noVotes += votingPower;
        }
        currentVote.hasVoted[msg.sender] = true;

        emit Voted(_voteId, msg.sender, _voteYes, _stakeAmount, _stakePeriod, votingPower);

        // Если суммарная сила голосов достигла или превысила порог, завершаем голосование
        if (currentVote.yesVotes + currentVote.noVotes >= currentVote.threshold) {
            concludeVote(_voteId);
        }
    }

    /// @notice Завершает голосование, отмечая его как завершённое и генерируя событие
    /// @param _voteId Идентификатор голосования
    function concludeVote(uint256 _voteId) internal {
        Vote storage currentVote = votes[_voteId];
        require(!currentVote.concluded, "Vote already concluded");
        currentVote.concluded = true;
        emit VoteConcluded(_voteId, currentVote.yesVotes, currentVote.noVotes);
    }

    /// @notice Получить данные голосования (без информации о том, кто голосовал)
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
