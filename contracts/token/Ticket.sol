// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";
import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";

import "./ControlledToken.sol";
import "./TicketInterface.sol";

/// @title 用户申购后就会获得 Ticket
contract Ticket is ControlledToken, TicketInterface {
  using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

  bytes32 constant private TREE_KEY = keccak256("PoolTogether/Ticket");
  uint256 constant private MAX_TREE_LEAVES = 5;

  // Ticket-weighted odds
  // 存储用户持有 token 的权重
  SortitionSumTreeFactory.SortitionSumTrees internal sortitionSumTrees;

  /// @notice Initializes the Controlled Token with Token Details and the Controller
  /// @param _name The name of the Token
  /// @param _symbol The symbol for the Token
  /// @param _decimals The number of decimals for the Token
  /// @param _controller Address of the Controller contract for minting & burning
  function initialize(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    TokenControllerInterface _controller
  )
    public
    virtual
    override
    initializer
  {
    super.initialize(_name, _symbol, _decimals, _controller);
    sortitionSumTrees.createTree(TREE_KEY, MAX_TREE_LEAVES);
  }

  /// @comment 返回用户的中奖概率
  /// @notice Returns the user's chance of winning.
  function chanceOf(address user) external view returns (uint256) {
    return sortitionSumTrees.stakeOf(TREE_KEY, bytes32(uint256(user)));
  }

  /// @comment 传入一个随机数，返回中奖用户的 address
  /// @notice Selects a user using a random number.  The random number will be uniformly bounded to the ticket totalSupply.
  /// @param randomNumber The random number to use to select a user.
  /// @return The winner
  function draw(uint256 randomNumber) external view override returns (address) {
    uint256 bound = totalSupply();
    address selected;
    if (bound == 0) {
      selected = address(0);
    } else {
      // 随机数
      uint256 token = UniformRandomNumber.uniform(randomNumber, bound);
      // 根据随机数拿到用户
      selected = address(uint256(sortitionSumTrees.draw(TREE_KEY, token)));
    }
    return selected;
  }

  /// @comment token transfers controller 之前，会触发该方法，用户更新用户的持有 token 情况
  /// @dev Controller hook to provide notifications & rule validations on token transfers to the controller.
  /// This includes minting and burning.
  /// May be overridden to provide more granular control over operator-burning
  /// @param from Address of the account sending the tokens (address(0x0) on minting)
  /// @param to Address of the account receiving the tokens (address(0x0) on burning)
  /// @param amount Amount of tokens being transferred
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);

    // optimize: ignore transfers to self
    if (from == to) {
      return;
    }

    if (from != address(0)) {
      uint256 fromBalance = balanceOf(from).sub(amount);
      sortitionSumTrees.set(TREE_KEY, fromBalance, bytes32(uint256(from)));
    }

    if (to != address(0)) {
      uint256 toBalance = balanceOf(to).add(amount);
      sortitionSumTrees.set(TREE_KEY, toBalance, bytes32(uint256(to)));
    }
  }

}
