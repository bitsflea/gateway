pragma solidity >=0.8.0 <0.9.0;

// SPDX-License-Identifier: MIT

import "./interface/IERC20.sol";

contract Gateway {
    address public owner;
    string public constant SYMBOL = "HT";

    struct Record {
        address user;
        uint256 amount;
        string symbol;
    }

    mapping(uint64 => Record) public records;
    mapping(string => IERC20) public erc20s;

    constructor() {
        owner = msg.sender;
    }

    event Recharge(
        address indexed sender,
        uint256 value,
        string symbol,
        string target
    );
    event PayOrder(
        address indexed sender,
        uint256 value,
        string symbol,
        uint128 order
    );
    event Withdraw(address indexed user, uint256 amount, string symbol);

    fallback() external payable {
        if (msg.data[1] == ":") {
            if (msg.data[0] == "p") {
                bytes memory bs = bytes(msg.data[2:]);
                uint128 id = uint128(toUint(bs));
                emit PayOrder(msg.sender, msg.value, SYMBOL, id);
            } else if (msg.data[0] == "r") {
                string memory toUser = string(bytes(msg.data[2:]));
                emit Recharge(msg.sender, msg.value, SYMBOL, toUser);
            }
        }
    }

    function createWithdraw(
        uint64 id,
        address user,
        uint256 amount,
        string memory symbol
    ) external {
        require(msg.sender == owner, "owner only");
        require(user != address(0), "user is zero address");
        require(records[id].user == address(0), "already exists");
        if (
            keccak256(abi.encodePacked(symbol)) ==
            keccak256(abi.encodePacked(SYMBOL))
        ) {
            require(address(this).balance >= amount, "balance not enough");
        } else {
            require(address(erc20s[symbol]) != address(0), "Invalid symbol");
            require(
                erc20s[symbol].balanceOf(address(this)) >= amount,
                "balance not enough"
            );
        }
        Record storage rec = records[id];
        rec.user = user;
        rec.amount = amount;
        rec.symbol = symbol;
    }

    function withdraw(uint64 id) external {
        address user = records[id].user;
        uint256 amount = records[id].amount;
        string memory symbol = records[id].symbol;
        require(user != address(0), "id does not exist");
        delete records[id];
        if (
            keccak256(abi.encodePacked(symbol)) ==
            keccak256(abi.encodePacked(SYMBOL))
        ) {
            payable(user).transfer(amount);
        } else {
            IERC20 erc = erc20s[symbol];
            erc.transfer(user, amount);
        }
        emit Withdraw(user, amount, symbol);
    }

    function toUint(bytes memory data) internal pure returns (uint256 result) {
        uint256 i;
        result = 0;
        for (i = 0; i < data.length; i++) {
            uint256 c = uint256(uint8(data[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }

    /***********erc20**********/

    function addERC20(IERC20 erc) external {
        require(msg.sender == owner, "owner only");
        erc20s[erc.symbol()] = erc;
    }

    function removeERC20(IERC20 erc) external {
        require(msg.sender == owner, "owner only");
        require(erc20s[erc.symbol()] == erc, "Invalid address");
        delete erc20s[erc.symbol()];
        erc.transfer(owner, erc.balanceOf(address(this)));
    }

    function rechargeERC20(
        string memory to,
        string memory symbol,
        uint256 amount
    ) external {
        require(address(erc20s[symbol]) != address(0), "Invalid symbol");
        require(
            bytes(to).length > 0 && bytes(to).length <= 12,
            "Invalid to user address"
        );
        IERC20 erc = erc20s[symbol];
        erc.transferFrom(msg.sender, address(this), amount);
        emit Recharge(msg.sender, amount, symbol, to);
    }

    function payOrderERC20(
        uint128 orderId,
        uint256 amount,
        string memory symbol
    ) external {
        require(address(erc20s[symbol]) != address(0), "Invalid symbol");
        IERC20 erc = erc20s[symbol];
        erc.transferFrom(msg.sender, address(this), amount);
        emit PayOrder(msg.sender, amount, symbol, orderId);
    }
}
