// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC1155Locker is Ownable, ReentrancyGuard {
    
    struct TimeLock {
        uint256 totalAmount;
        uint256 releaseTime; // When the tokens can be released
        uint256 releaseInterval; // Time between releases
        uint256 amountPerInterval; // Amount released each interval
        uint256 releasedAmount; // Total amount already released
    }

    // Mapping user address => token contract address => token ID => vesting information
    mapping(address => mapping(address => mapping(uint256 => TimeLock))) public erc1155Locks;

    event ERC1155Locked(address indexed user, address indexed tokenAddress, uint256 tokenId, uint256 amount);
    event ERC1155Unlocked(address indexed user, address indexed tokenAddress, uint256 tokenId, uint256 amount);

    function lockERC1155(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 releaseInterval,
        uint256 amountPerInterval
    ) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        require(releaseInterval > 0, "Release interval must be greater than zero");
        require(amountPerInterval > 0, "Amount per interval must be greater than zero");

        IERC1155(tokenAddress).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        erc1155Locks[msg.sender][tokenAddress][tokenId] = TimeLock({
            totalAmount: amount,
            releaseTime: block.timestamp + releaseInterval,
            releaseInterval: releaseInterval,
            amountPerInterval: amountPerInterval,
            releasedAmount: 0
        });

        emit ERC1155Locked(msg.sender, tokenAddress, tokenId, amount);
    }

    function unlockERC1155(address tokenAddress, uint256 tokenId) external nonReentrant {
        TimeLock storage lockInfo = erc1155Locks[msg.sender][tokenAddress][tokenId];
        require(lockInfo.totalAmount > 0, "No tokens are locked");
        require(block.timestamp >= lockInfo.releaseTime, "Tokens are still locked");

        uint256 intervalsPassed = (block.timestamp - lockInfo.releaseTime) / lockInfo.releaseInterval;
        uint256 amountToRelease = intervalsPassed * lockInfo.amountPerInterval;

        uint256 releasableAmount = amountToRelease > (lockInfo.totalAmount - lockInfo.releasedAmount)
            ? (lockInfo.totalAmount - lockInfo.releasedAmount)
            : amountToRelease;
        
        require(releasableAmount > 0, "No tokens available for release");

        lockInfo.releasedAmount += releasableAmount;
        lockInfo.releaseTime = block.timestamp + lockInfo.releaseInterval;

        IERC1155(tokenAddress).safeTransferFrom(address(this), msg.sender, tokenId, releasableAmount, "");

        emit ERC1155Unlocked(msg.sender, tokenAddress, tokenId, releasableAmount);
    }
    // Mapping user => token contract => vesting information for ERC20
mapping(address => mapping(address => TimeLock)) public erc20Locks;

event ERC20Locked(address indexed user, address indexed tokenAddress, uint256 amount);
event ERC20Unlocked(address indexed user, address indexed tokenAddress, uint256 amount);

function lockERC20(
    address tokenAddress,
    uint256 amount,
    uint256 releaseInterval,
    uint256 amountPerInterval
) external nonReentrant {
    require(amount > 0, "Amount must be greater than zero");

    IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

    erc20Locks[msg.sender][tokenAddress] = TimeLock({
        totalAmount: amount,
        releaseTime: block.timestamp + releaseInterval,
        releaseInterval: releaseInterval,
        amountPerInterval: amountPerInterval,
        releasedAmount: 0
    });

    emit ERC20Locked(msg.sender, tokenAddress, amount);
}

function unlockERC20(address tokenAddress) external nonReentrant {
    TimeLock storage lockInfo = erc20Locks[msg.sender][tokenAddress];
    require(lockInfo.totalAmount > 0, "No tokens are locked");
    require(block.timestamp >= lockInfo.releaseTime, "Tokens are still locked");

    uint256 intervalsPassed = (block.timestamp - lockInfo.releaseTime) / lockInfo.releaseInterval;
    uint256 amountToRelease = intervalsPassed * lockInfo.amountPerInterval;

    uint256 releasableAmount = amountToRelease > (lockInfo.totalAmount - lockInfo.releasedAmount)
        ? (lockInfo.totalAmount - lockInfo.releasedAmount)
        : amountToRelease;

    require(releasableAmount > 0, "No tokens available for release");

    lockInfo.releasedAmount += releasableAmount;
    lockInfo.releaseTime = block.timestamp + lockInfo.releaseInterval;

    IERC20(tokenAddress).transfer(msg.sender, releasableAmount);

    emit ERC20Unlocked(msg.sender, tokenAddress, releasableAmount);
}
// Mapping user => token contract => token ID => lock information for ERC721
mapping(address => mapping(address => mapping(uint256 => bool))) public erc721Locks;

event ERC721Locked(address indexed user, address indexed tokenAddress, uint256 tokenId);
event ERC721Unlocked(address indexed user, address indexed tokenAddress, uint256 tokenId);

function lockERC721(address tokenAddress, uint256 tokenId) external nonReentrant {
    IERC721(tokenAddress).transferFrom(msg.sender, address(this), tokenId);
    erc721Locks[msg.sender][tokenAddress][tokenId] = true;
    emit ERC721Locked(msg.sender, tokenAddress, tokenId);
}

function unlockERC721(address tokenAddress, uint256 tokenId) external nonReentrant {
    require(erc721Locks[msg.sender][tokenAddress][tokenId], "No such NFT is locked");

    IERC721(tokenAddress).transferFrom(address(this), msg.sender, tokenId);
    erc721Locks[msg.sender][tokenAddress][tokenId] = false;

    emit ERC721Unlocked(msg.sender, tokenAddress, tokenId);
}

}

