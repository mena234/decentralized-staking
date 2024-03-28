// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";
import "hardhat/console.sol";

error Staker__DeadlineDidNotPassed();
error Staker__AddressNotStacker(address userAddress);
error Staker__WithdrawFailed();
error Stacker__NotAllowedToWidthraw();
error Staker__AlreadyExecuted();
error Staker__DeadlinePassed();
error Staker__ExternalContractCompleted();

contract Staker {
	event Stake(address indexed userAddress, uint256 indexed value);

	ExampleExternalContract public exampleExternalContract;
	mapping(address => uint256) public balances;
	bool public executed = false;
	uint256 public constant THRESHOLD = 1 ether;
	uint256 public deadline = block.timestamp + 72 hours;
	bool public openForWithdraw = false;

  modifier notCompleted {
    if (exampleExternalContract.completed()) {
      revert Staker__ExternalContractCompleted();
    }
    _;
  }

	constructor(address exampleExternalContractAddress) {
		exampleExternalContract = ExampleExternalContract(
			exampleExternalContractAddress
		);
	}

	// Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
	// (Make sure to add a `Stake(address,uint256)` event and emit it for the frontend `All Stakings` tab to display)
	function stake() public payable {
    address userAddress = msg.sender;
		if (block.timestamp >= deadline) {
			revert Staker__DeadlinePassed();
		}

		balances[userAddress] += msg.value;
		emit Stake(userAddress, msg.value);
	}

	// After some `deadline` allow anyone to call an `execute()` function
	// If the deadline has passed and the threshold is met, it should call `exampleExternalContract.complete{value: address(this).balance}()`

	function execute() public notCompleted {
		if (block.timestamp < deadline) {
			revert Staker__DeadlineDidNotPassed();
		}

		if (address(this).balance < THRESHOLD) {
			openForWithdraw = true;
		} else {
			exampleExternalContract.complete{ value: address(this).balance }();
		}

		executed = true;
	}

	// If the `threshold` was not met, allow everyone to call a `withdraw()` function to withdraw their balance
	function withdraw() public notCompleted {
		if (!openForWithdraw) {
			revert Stacker__NotAllowedToWidthraw();
		}

		if (balances[msg.sender] == 0) {
			revert Staker__AddressNotStacker(msg.sender);
		}

		(bool success, ) = payable(msg.sender).call{
			value: address(this).balance
		}("");

		if (!success) {
			revert Staker__WithdrawFailed();
		}
	}

	// Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
	function timeLeft() public view returns (uint256) {
		if (block.timestamp >= deadline) {
			return 0;
		} else {
			return deadline - block.timestamp;
		}
	}

	// Add the `receive()` special function that receives eth and calls stake()

	receive() external payable {
		stake();
	}
}
