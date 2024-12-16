// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AaveETHManager, IAEth} from "./AAVEETHManager.sol";

contract aaveIntents {
    address public immutable aaveManager;
    address public immutable aEthAddress;
    IAEth private immutable aEth;
    error InvalidSyntax();
    error InvalidCharacter();

    struct StringPart {
        uint256 start;
        uint256 end;
    }

    constructor(address payable _aaveManager, address _aEthAddress) {
        require(_aaveManager != address(0), "Invalid manager address");
        aaveManager = _aaveManager;
        aEthAddress = _aEthAddress;
        aEth = IAEth(_aEthAddress);
    }

    function command(string calldata intent) external payable {
        bytes memory normalized = _lowercase(bytes(intent));
        bytes32 action = _extraction(normalized);

        if (action == keccak256("deposit")) {
            bytes memory amount = _extractAmount(normalized);
            _deposit(_toUint(amount, 18,true));
        } else if (action == keccak256("withdraw")) {
            bytes memory amount = _extractAmount(normalized);
            _withdraw(_toUint(amount,18,false));
            (bool ok, ) = payable(msg.sender).call{value: address(this).balance}("");
            require(ok, "Withdrawal failed.");
        } else {
            revert InvalidSyntax();
        }
    }

    function _deposit(uint256 amount) internal {
        require(msg.value == amount, "Ether sent mismatch with amount.");
        (bool success, ) = aaveManager.call{value: amount}(abi.encodeWithSignature("depositETH()"));
        require(success, "Deposit failed.");
        aEth.transfer(msg.sender, aEth.balanceOf(address(this)));
    }

    function _withdraw(uint256 amount) internal {
        (bool success, ) = aaveManager.call(abi.encodeWithSignature("withdrawETH(uint256)", amount));
        require(success, "Withdrawal failed.");
    }

    function _extractAmount(bytes memory normalizedIntent)
        internal
        pure
        returns (bytes memory amount)
    {
        StringPart[] memory parts = _split(normalizedIntent, " ");
        if (parts.length != 3) revert InvalidSyntax(); // Expect "action amount ETH"
        return _getPart(normalizedIntent, parts[1]);   // Extract the "amount" part
    }

    function _slice(bytes memory data, uint256 start, uint256 end) 
    internal 
    pure 
    returns (bytes memory) 
{
    require(end >= start && end <= data.length, "Invalid slice range");
    bytes memory result = new bytes(end - start);
    for (uint256 i = start; i < end; i++) {
        result[i - start] = data[i];
    }
    return result;
}

function _extraction(bytes memory normalizedIntent) internal pure returns (bytes32) {
    uint256 len = normalizedIntent.length;
    for (uint256 i = 0; i < len; i++) {
        if (normalizedIntent[i] == 0x20) { // Detect space
            return keccak256(_slice(normalizedIntent, 0, i)); // Use the slice helper
        }
    }
    revert InvalidSyntax(); // If no space is found, the input is invalid
}


    function _split(bytes memory base, string memory delimiter)
        internal
        pure
        returns (StringPart[] memory parts)
    {
        require(bytes(delimiter).length == 1, "Delimiter must be one character");
        bytes1 del = bytes(delimiter)[0];
        uint256 len = base.length;
        uint256 count;

        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                if (base[i] == del) count++;
            }

            parts = new StringPart[](count + 1);
            uint256 partIndex;
            uint256 start;

            for (uint256 i; i <= len; ++i) {
                if (i == len || base[i] == del) {
                    parts[partIndex++] = StringPart(start, i);
                    start = i + 1;
                }
            }
        }
    }

    function _getPart(bytes memory base, StringPart memory part)
        internal
        pure
        returns (bytes memory result)
    {
        result = new bytes(part.end - part.start);
        for (uint256 i = 0; i < result.length; ++i) {
            result[i] = base[part.start + i];
        }
    }

    function _lowercase(bytes memory subject) internal pure returns (bytes memory result) {
        result = new bytes(subject.length);
        for (uint256 i = 0; i < subject.length; ++i) {
            bytes1 b = subject[i];
            result[i] = (b >= 0x41 && b <= 0x5A) ? bytes1(uint8(b) + 32) : b;
        }
    }

    function _toUint(bytes memory s, uint256 decimals, bool scale) internal pure returns (uint256 result) {
        unchecked {
            uint256 len = s.length;
            bool hasDecimal;
            uint256 decimalPlaces;
    
            for (uint256 i; i < len; ++i) {
                bytes1 c = s[i];
                if (c >= 0x30 && c <= 0x39) { // '0' to '9'
                    result = result * 10 + (uint256(uint8(c)) - 48);
                    if (hasDecimal) {
                        if (++decimalPlaces > decimals) break;
                    }
                } else if (c == 0x2E && !hasDecimal) { // '.'
                    hasDecimal = true;
                } else {
                    revert InvalidCharacter();
                }
            }
    
            if (scale) {
                if (!hasDecimal) result *= 10**decimals;
                else if (decimalPlaces < decimals) result *= 10**(decimals - decimalPlaces);
            }
        }
    }

    receive() external payable {}

    fallback() external payable {}
    
}