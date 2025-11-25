// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract BankTreasury {
    // -------------------- Ownable --------------------
    address public owner;
    event OwnershipTransferred(address indexed prev, address indexed next);
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address next) external onlyOwner {
        require(next != address(0), "ZERO_ADDR");
        emit OwnershipTransferred(owner, next);
        owner = next;
    }

    // -------------------- Reentrancy Guard ---------------------
    uint256 private _guard;
    modifier nonReentrant() {
        require(_guard == 0, "REENTRANT");
        _guard = 1;
        _;
        _guard = 0;
    }

    // ------------------------------------------------------------
    //                ONE UNIFIED TABLE STRUCT
    // ------------------------------------------------------------

    struct Table {
        // config
        bool allowed;
        uint256 maxExposure;
        uint256 floatLimit;
        // runtime state
        uint256 exposure;
        uint256 floatOut;
        uint256 feesPaid;
    }

    mapping(address => Table) public tables;

    // Totals
    uint256 public totalExposure;
    uint256 public totalFloatOut;

    // -------------------- Events ----------------------------
    event TableAuthorized(
        address indexed table,
        uint256 maxExposure,
        uint256 floatLimit
    );
    event TableUpdated(
        address indexed table,
        uint256 maxExposure,
        uint256 floatLimit,
        bool allowed
    );

    event ExposureLocked(
        address indexed table,
        uint256 delta,
        uint256 newExposure,
        uint256 total
    );
    event ExposureReleased(
        address indexed table,
        uint256 delta,
        uint256 newExposure,
        uint256 total
    );

    event FloatRequested(
        address indexed table,
        uint256 amount,
        uint256 tableFloat,
        uint256 total
    );
    event FloatReturned(
        address indexed table,
        uint256 amount,
        uint256 tableFloat,
        uint256 total
    );

    event FeeReceived(
        address indexed table,
        uint256 amount,
        uint256 cumulative
    );
    event OwnerDeposit(address indexed from, uint256 amount);
    event OwnerWithdraw(address indexed to, uint256 amount);

    // -------------------- Modifiers ----------------------------
    modifier onlyTable() {
        require(tables[msg.sender].allowed, "TABLE_NOT_AUTH");
        _;
    }

    // -------------------- Bankroll View ----------------------
    function totalBankroll() public view returns (uint256) {
        return address(this).balance + totalFloatOut;
    }

    function availableForFloat() public view returns (uint256) {
        return address(this).balance;
    }

    // -------------------- Admin: table control -----------------
    function authorizeTable(
        address table,
        uint256 maxExposure,
        uint256 floatLimit
    ) external onlyOwner {
        require(table != address(0), "ZERO_ADDR");
        require(!tables[table].allowed, "ALREADY_AUTH");

        tables[table] = Table({
            allowed: true,
            maxExposure: maxExposure,
            floatLimit: floatLimit,
            exposure: 0,
            floatOut: 0,
            feesPaid: 0
        });

        emit TableAuthorized(table, maxExposure, floatLimit);
    }

    function updateTable(
        address table,
        uint256 maxExposure,
        uint256 floatLimit,
        bool allowed
    ) external onlyOwner {
        require(table != address(0), "ZERO_ADDR");
        require(tables[table].allowed || allowed, "NOT_AUTHED");

        Table storage t = tables[table];
        t.maxExposure = maxExposure;
        t.floatLimit = floatLimit;
        t.allowed = allowed;

        emit TableUpdated(table, maxExposure, floatLimit, allowed);
    }

    // Admin: bankroll ops
    function depositBankroll() external payable onlyOwner {
        require(msg.value > 0, "NO_VALUE");
        emit OwnerDeposit(msg.sender, msg.value);
    }

    function withdrawBankroll(
        address payable to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(amount <= address(this).balance, "INSUFFICIENT_AVAILABLE");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "WITHDRAW_FAIL");
        emit OwnerWithdraw(to, amount);
    }

    // Table: exposure
    function lockExposure(uint256 delta) external onlyTable {
        if (delta == 0) return;
        Table storage t = tables[msg.sender];

        uint256 newExp = t.exposure + delta;
        require(newExp <= t.maxExposure, "EXPOSURE_LIMIT");

        t.exposure = newExp;
        totalExposure += delta;

        emit ExposureLocked(msg.sender, delta, newExp, totalExposure);
    }

    function releaseExposure(uint256 delta) external onlyTable {
        if (delta == 0) return;

        Table storage t = tables[msg.sender];
        require(delta <= t.exposure, "EXPOSURE_UNDERFLOW");

        t.exposure -= delta;
        totalExposure -= delta;

        emit ExposureReleased(msg.sender, delta, t.exposure, totalExposure);
    }

    // Table: float management
    function requestFloat(uint256 amount) external onlyTable nonReentrant {
        require(amount > 0, "ZERO_AMT");
        Table storage t = tables[msg.sender];

        require(t.floatOut + amount <= t.floatLimit, "FLOAT_LIMIT");
        require(amount <= address(this).balance, "INSUFFICIENT_TREASURY");

        t.floatOut += amount;
        totalFloatOut += amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "FLOAT_FAIL");

        emit FloatRequested(msg.sender, amount, t.floatOut, totalFloatOut);
    }

    function returnFloat() external payable onlyTable nonReentrant {
        uint256 amount = msg.value;
        require(amount > 0, "ZERO_AMT");

        Table storage t = tables[msg.sender];
        require(amount <= t.floatOut, "RETURN_GT_FLOAT");

        t.floatOut -= amount;
        totalFloatOut -= amount;

        emit FloatReturned(msg.sender, amount, t.floatOut, totalFloatOut);
    }

    // Fees
    function depositFee() external payable onlyTable {
        require(msg.value > 0, "NO_VALUE");
        Table storage t = tables[msg.sender];

        t.feesPaid += msg.value;
        emit FeeReceived(msg.sender, msg.value, t.feesPaid);
    }

    // Fallback
    receive() external payable {}

    fallback() external payable {}
}
