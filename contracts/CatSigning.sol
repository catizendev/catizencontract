// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract CatSigning is ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    struct CallData {
        uint256 blocknumber;
        address wallet;
        string comment;
    }

    struct CallDataWithPay {
        uint256 blocknumber;
        address wallet;
        uint256 amount;
        string comment;
    }

    struct CallDataWithPayERC20 {
        uint256 blocknumber;
        uint256 tokenid;
        address wallet;
        uint256 amount;
        string comment;
    }

    struct SendData {
        address token;
        address toWallet;
        uint256 amount;
        string comment;
    }

    CallData[] public dataTaskSign;
    CallData[] public dataGameSign;
    CallDataWithPay[] public dataGameRecharge;

    mapping(uint256 => address) public tokenGameRecharge;
    CallDataWithPayERC20[] public dataGameRechargeERC20;

    mapping(address => uint256) public batch_sender;
    mapping(uint256 => uint256) public batch_done;

    uint256[47] private __gap;

    event OnTaskSign(
        uint256 index,
        uint256 timestamp,
        address wallet,
        string comment
    );
    event OnGameSign(
        uint256 index,
        uint256 timestamp,
        address wallet,
        string comment
    );
    event OnGameRecharge(
        uint256 index,
        uint256 timestamp,
        address wallet,
        uint amount,
        string comment
    );
    event OnGameRechargeERC20(
        uint256 index,
        uint256 timestamp,
        uint256 tokenid,
        address wallet,
        uint amount,
        string comment
    );
    event OnFallback(
        uint256 index,
        uint256 timestamp,
        address wallet,
        uint amount,
        string comment
    );
    // bytes comment
    event OnMasterWithdraw(address wallet, address token, uint amount);

    constructor() {}

    function initialize() external initializer {
        __Ownable_init();
    }

    function taskSign(string memory comment) public payable {
        dataTaskSign.push(CallData(block.number, msg.sender, comment));
        emit OnTaskSign(
            dataTaskSign.length.sub(1),
            block.timestamp,
            msg.sender,
            comment
        );
    }

    function gameSign(string memory comment) public payable {
        dataGameSign.push(CallData(block.number, msg.sender, comment));
        emit OnGameSign(
            dataGameSign.length.sub(1),
            block.timestamp,
            msg.sender,
            comment
        );
    }

    function gameRecharge(string memory comment) external payable {
        dataGameRecharge.push(
            CallDataWithPay(block.number, msg.sender, msg.value, comment)
        );
        emit OnGameRecharge(
            dataGameRecharge.length.sub(1),
            block.timestamp,
            msg.sender,
            msg.value,
            comment
        );
    }

    function addRechargeERC20(
        uint256 tokenid,
        address token
    ) external onlyOwner {
        tokenGameRecharge[tokenid] = token;
    }

    function gameRechargeERC20(
        uint256 tokenid,
        uint256 amount,
        string memory comment
    ) external {
        dataGameRechargeERC20.push(
            CallDataWithPayERC20(
                block.number,
                tokenid,
                msg.sender,
                amount,
                comment
            )
        );
        require(tokenGameRecharge[tokenid] != address(0), "error tokenid");

        IERC20MetadataUpgradeable(tokenGameRecharge[tokenid]).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        emit OnGameRechargeERC20(
            dataGameRechargeERC20.length.sub(1),
            block.timestamp,
            tokenid,
            msg.sender,
            amount,
            comment
        );
    }

    function batchSendETH(
        uint256 amount,
        address[] memory users,
        string memory comment
    ) external payable {
        require(msg.value >= users.length.mul(amount), "!amount");
        for (uint256 i = 0; i < users.length; i++) {
            (bool sentok, ) = users[i].call{value: amount}(bytes(comment));
            require(sentok, "Failed to send Ether");
        }
    }

    function addBatchSender(address token, uint256 valueid) external onlyOwner {
        batch_sender[token] = valueid;
    }

    function batchSendAny(
        uint256 batchid,
        SendData[] memory data
    ) external payable {
        require(batch_done[batchid] == 0, "!batch_done");
        require(batch_sender[msg.sender] > 0, "!sender");

        batch_done[batchid] = block.number;

        for (uint256 i = 0; i < data.length; i++) {
            if (data[i].token == address(0)) {
                (bool sentok, ) = data[i].toWallet.call{value: data[i].amount}(
                    bytes(data[i].comment)
                );
                require(sentok, "Failed to send Ether");
            } else {
                IERC20MetadataUpgradeable(data[i].token).safeTransfer(
                    data[i].toWallet,
                    data[i].amount
                );
            }
        }
    }

    function queryIndex() external view returns (uint, uint, uint) {
        return (
            dataTaskSign.length,
            dataGameSign.length,
            dataGameRecharge.length
        );
    }

    function withdrawTokenA(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20MetadataUpgradeable(token).safeTransfer(msg.sender, amount);
        }
        emit OnMasterWithdraw(msg.sender, token, amount);
    }

    fallback() external payable {
        if (msg.data.length < 3) return;
        if (msg.data[1] != 0x3a) return;

        string memory comment = string(msg.data[2:]);
        if (msg.data[0] == 0x61) {
            this.taskSign(comment);
        }
        if (msg.data[0] == 0x62) {
            this.gameSign(comment);
        }
        if (msg.data[0] == 0x63) {
            require(msg.value > 0, "!c:value");
            this.gameRecharge{value: msg.value}(comment);
        }
    }

    receive() external payable {
        // bytes memory converted = new bytes(2);
        emit OnFallback(9998, block.timestamp, msg.sender, msg.value, "");
    }
}
