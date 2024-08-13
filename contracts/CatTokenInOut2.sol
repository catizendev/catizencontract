// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract CatTokenInOut2 is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    struct CallDataWithPayERC20 {
        uint256 blockNumber;
        uint256 tokenId;
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

    mapping(uint256 => address) public tokenGameRecharge;
    CallDataWithPayERC20[] public dataGameRechargeERC20;

    mapping(address => uint256) public allowSender;
    mapping(uint256 => uint256) public doneBatchId;
    mapping(address => address) public canWithdrawTo;

    uint256[50] private __gap;

    event OnGameRechargeERC20(
        uint256 index,
        uint256 timestamp,
        uint256 tokenId,
        address wallet,
        uint256 amount,
        string comment
    );

    event OnFallback(
        uint256 index,
        uint256 timestamp,
        address wallet,
        uint256 amount,
        string comment
    );

    event OnMasterWithdraw(
        address wallet,
        address toAddress,
        address token,
        uint256 amount
    );

    function initialize() external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        allowSender[msg.sender] = block.number;
        canWithdrawTo[msg.sender] = msg.sender;
    }

    function setRechargeERC20(
        uint256 tokenId,
        address token
    ) external onlyOwner {
        require(token != address(0), "Invalid token address");
        tokenGameRecharge[tokenId] = token;
    }

    function setAllowSender(
        address wallet,
        uint256 valueId
    ) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        allowSender[wallet] = valueId;
    }

    function setCanWithdraw(
        address callWallet,
        address toWallet
    ) external onlyOwner {
        require(callWallet != address(0), "Invalid addresses");
        canWithdrawTo[callWallet] = toWallet;
    }

    function gameRecharge(
        string memory comment
    ) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Amount must be greater than zero");

        uint256 amount = msg.value;
        dataGameRechargeERC20.push(
            CallDataWithPayERC20(block.number, 0, msg.sender, amount, comment)
        );

        emit OnGameRechargeERC20(
            dataGameRechargeERC20.length.sub(1),
            block.timestamp,
            0,
            msg.sender,
            amount,
            comment
        );
    }

    function gameRechargeERC20(
        uint256 tokenId,
        uint256 amount,
        string memory comment
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        require(tokenGameRecharge[tokenId] != address(0), "Invalid tokenId");

        dataGameRechargeERC20.push(
            CallDataWithPayERC20(
                block.number,
                tokenId,
                msg.sender,
                amount,
                comment
            )
        );

        IERC20MetadataUpgradeable(tokenGameRecharge[tokenId]).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        emit OnGameRechargeERC20(
            dataGameRechargeERC20.length.sub(1),
            block.timestamp,
            tokenId,
            msg.sender,
            amount,
            comment
        );
    }

    function batchSendAny(
        uint256 batchId,
        SendData[] memory data
    ) external payable nonReentrant whenNotPaused {
        require(doneBatchId[batchId] == 0, "Batch already processed");
        require(allowSender[msg.sender] > 0, "Sender not authorized");

        doneBatchId[batchId] = block.number;

        for (uint256 i = 0; i < data.length; i++) {
            require(data[i].amount > 0, "Amount must be greater than zero");

            if (data[i].token == address(0)) {
                _sendEther(data[i].toWallet, data[i].amount, data[i].comment);
            } else {
                _sendERC20(data[i].token, data[i].toWallet, data[i].amount);
            }
        }
    }

    function queryIndex() external view returns (uint256) {
        return dataGameRechargeERC20.length;
    }

    function withdrawTokenA(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(allowSender[msg.sender] > 0, "Sender not authorized");
        require(
            canWithdrawTo[msg.sender] != address(0),
            "Withdrawal not allowed"
        );

        if (token == address(0)) {
            _sendEther(canWithdrawTo[msg.sender], amount, "");
        } else {
            _sendERC20(token, canWithdrawTo[msg.sender], amount);
        }

        emit OnMasterWithdraw(
            msg.sender,
            canWithdrawTo[msg.sender],
            token,
            amount
        );
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    fallback() external payable {
        emit OnFallback(9998, block.timestamp, msg.sender, msg.value, "");
    }

    receive() external payable {
        emit OnFallback(9999, block.timestamp, msg.sender, msg.value, "");
    }

    // Internal functions

    function _sendEther(
        address to,
        uint256 amount,
        string memory comment
    ) internal {
        (bool sentOk, ) = to.call{value: amount}(bytes(comment));
        require(sentOk, "Failed to send Ether");
    }

    function _sendERC20(address token, address to, uint256 amount) internal {
        IERC20MetadataUpgradeable(token).safeTransfer(to, amount);
    }
}
