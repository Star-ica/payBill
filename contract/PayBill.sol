// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Bill payments with on-chain receipts and prepaid recurring schedules.
/// The admin registers billers. Payments are forwarded straight to the biller's wallet.
contract PayBill {
    address public admin = msg.sender;
    struct Biller { string name; string category; address wallet; bool active; }
    struct Receipt { address payer; uint256 biller; string ref; uint256 amount; uint256 time; }
    struct Schedule { address payer; uint256 biller; string ref; uint256 amount; uint256 interval; uint256 remaining; uint256 nextDue; bool active; }

    Biller[] private billers;
    Receipt[] private receipts;
    Schedule[] private schedules;
    mapping(address => uint256[]) private byPayer;
    mapping(address => uint256[]) private byWallet;
    mapping(address => uint256[]) private schedByPayer;
    bool private locked;

    event BillerAdded(uint256 indexed id, string name, address wallet);
    event BillerStatus(uint256 indexed id, bool active);
    event Paid(uint256 indexed receiptId, address indexed payer, uint256 indexed biller, uint256 amount);
    event ScheduleCreated(uint256 indexed id, address indexed payer, uint256 biller);
    event ScheduleCancelled(uint256 indexed id);

    modifier onlyAdmin() { require(msg.sender == admin, "admin only"); _; }
    modifier nonReentrant() { require(!locked, "reentrant"); locked = true; _; locked = false; }

    function transferAdmin(address a) external onlyAdmin { require(a != address(0), "zero"); admin = a; }

    function addBiller(string calldata name, string calldata category, address wallet) external onlyAdmin returns (uint256 id) {
        require(wallet != address(0) && bytes(name).length > 0, "invalid");
        id = billers.length;
        billers.push(Biller(name, category, wallet, true));
        emit BillerAdded(id, name, wallet);
    }
    function setBillerActive(uint256 id, bool active) external onlyAdmin { billers[id].active = active; emit BillerStatus(id, active); }
    function billerCount() external view returns (uint256) { return billers.length; }
    function getBiller(uint256 id) external view returns (string memory, string memory, address, bool) {
        Biller storage b = billers[id]; return (b.name, b.category, b.wallet, b.active);
    }

    function _pay(address payer, uint256 bid, string memory ref, uint256 amt) internal {
        address wallet = billers[bid].wallet;
        uint256 id = receipts.length;
        receipts.push(Receipt(payer, bid, ref, amt, block.timestamp));
        byPayer[payer].push(id); byWallet[wallet].push(id);
        (bool ok, ) = payable(wallet).call{value: amt}("");
        require(ok, "transfer failed");
        emit Paid(id, payer, bid, amt);
    }

    function pay(uint256 bid, string calldata ref) external payable nonReentrant {
        require(bid < billers.length && billers[bid].active, "biller unavailable");
        require(msg.value > 0 && bytes(ref).length > 0, "invalid");
        _pay(msg.sender, bid, ref, msg.value);
    }

    /// Deposit the full amount up front; it is split evenly across `count` payments.
    function createSchedule(uint256 bid, string calldata ref, uint256 intervalDays, uint256 count) external payable returns (uint256 id) {
        require(bid < billers.length && billers[bid].active, "biller unavailable");
        require(bytes(ref).length > 0 && intervalDays >= 1 && intervalDays <= 365 && count >= 1 && count <= 24, "invalid");
        require(msg.value > 0 && msg.value % count == 0, "deposit must split evenly");
        id = schedules.length;
        schedules.push(Schedule(msg.sender, bid, ref, msg.value / count, intervalDays * 1 days, count, block.timestamp, true));
        schedByPayer[msg.sender].push(id);
        emit ScheduleCreated(id, msg.sender, bid);
    }
    /// Anyone can trigger a due payment.
    function runSchedule(uint256 id) external nonReentrant {
        Schedule storage s = schedules[id];
        require(s.active && s.remaining > 0 && block.timestamp >= s.nextDue, "not due");
        require(billers[s.biller].active, "biller unavailable");
        s.remaining--; s.nextDue = block.timestamp + s.interval;
        if (s.remaining == 0) s.active = false;
        _pay(s.payer, s.biller, s.ref, s.amount);
    }
    function cancelSchedule(uint256 id) external nonReentrant {
        Schedule storage s = schedules[id];
        require(s.payer == msg.sender && s.active, "not allowed");
        uint256 refund = s.amount * s.remaining;
        s.active = false; s.remaining = 0;
        (bool ok, ) = payable(msg.sender).call{value: refund}("");
        require(ok, "refund failed");
        emit ScheduleCancelled(id);
    }

    function receiptCount() external view returns (uint256) { return receipts.length; }
    function getReceipt(uint256 id) external view returns (address, uint256, string memory, uint256, uint256) {
        Receipt storage r = receipts[id]; return (r.payer, r.biller, r.ref, r.amount, r.time);
    }
    function receiptsOf(address a) external view returns (uint256[] memory) { return byPayer[a]; }
    function receiptsOfWallet(address a) external view returns (uint256[] memory) { return byWallet[a]; }
    function scheduleCount() external view returns (uint256) { return schedules.length; }
    function getSchedule(uint256 id) external view returns (address, uint256, string memory, uint256) {
        Schedule storage s = schedules[id]; return (s.payer, s.biller, s.ref, s.amount);
    }
    function getScheduleState(uint256 id) external view returns (uint256, uint256, uint256, bool) {
        Schedule storage s = schedules[id]; return (s.interval, s.remaining, s.nextDue, s.active);
    }
    function schedulesOf(address a) external view returns (uint256[] memory) { return schedByPayer[a]; }
}
