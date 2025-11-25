// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BlackjackTable.sol";
import "./BankTreasury.sol";
import "./RNGCoordinator.sol";

/**
 * @title BlackjackTableFactory
 * @notice Deploys and tracks BlackjackTable instances that connect to a shared RNGCoordinator and BankTreasury.
 */
contract BlackjackTableFactory {
    struct TableInfo {
        address table;
        address dealer;
        uint256 minBet;
        uint256 maxBet;
        bool active;
    }

    address public owner;
    BankTreasury public immutable bank;
    CommitRevealRandom public immutable rng;

    uint256 public tableCount;
    mapping(uint256 => TableInfo) public tables;
    mapping(address => bool) public isTable;

    event TableDeployed(
        uint256 indexed id,
        address indexed table,
        address indexed dealer,
        uint256 minBet,
        uint256 maxBet
    );
    event OwnershipTransferred(address indexed prev, address indexed next);
    event TableStatusChanged(uint256 indexed id, bool active);

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(address payable _bank, address _rng) {
        owner = msg.sender;
        bank = BankTreasury(_bank);
        rng = CommitRevealRandom(_rng);
    }

    // ---------------------------------------------------------------------
    //  Owner controls
    // ---------------------------------------------------------------------

    function transferOwnership(address next) external onlyOwner {
        require(next != address(0), "ZERO_ADDR");
        emit OwnershipTransferred(owner, next);
        owner = next;
    }

    /**
     * @notice Deploys a new BlackjackTable, authorizes it in the BankTreasury, and registers it.
     * @param minBet Minimum bet amount in wei.
     * @param maxBet Maximum bet amount in wei.
     * @param maxExposure Maximum exposure (liability) the table may hold.
     * @param floatLimit Maximum float (ETH working capital) the table may withdraw from the treasury.
     * @return table The address of the newly deployed table.
     */
    function createTable(
        uint256 minBet,
        uint256 maxBet,
        uint256 maxExposure,
        uint256 floatLimit
    ) external onlyOwner returns (address table) {
        require(minBet > 0 && maxBet > minBet, "BAD_BETS");
        require(maxExposure > 0 && floatLimit > 0, "BAD_LIMITS");

        // Deploy new BlackjackTable; msg.sender becomes the dealer
        Blackjack t = new Blackjack(payable(address(bank)), address(rng));
        table = address(t);

        // Register table in BankTreasury for controlled bankroll exposure
        bank.authorizeTable(table, maxExposure, floatLimit);

        // Register in factory
        tableCount++;
        tables[tableCount] = TableInfo({
            table: table,
            dealer: msg.sender,
            minBet: minBet,
            maxBet: maxBet,
            active: true
        });
        isTable[table] = true;

        emit TableDeployed(tableCount, table, msg.sender, minBet, maxBet);
    }

    /**
     * @notice Enable or disable an existing table (e.g. maintenance, closure).
     */
    function setTableActive(uint256 tableId, bool active) external onlyOwner {
        TableInfo storage info = tables[tableId];
        require(info.table != address(0), "INVALID_ID");
        info.active = active;
        emit TableStatusChanged(tableId, active);
    }

    /**
     * @notice Returns the list of all deployed table addresses.
     */
    function listTables() external view returns (address[] memory list) {
        list = new address[](tableCount);
        for (uint256 i = 1; i <= tableCount; i++) {
            list[i - 1] = tables[i].table;
        }
    }
}
