## crypto_token_economy.gd - Cryptoeconomic Token System
## Part of Fantasy Town World-Breaking Demo
##
## A full cryptoeconomic system for agents with:
## - Token minting and burning
## - Staking for reputation
## - Transaction ledger (blockchain-style)
## - Bonding curves for price discovery
## - Governance voting with tokens
##
## Token Economics:
## - $CLAW tokens are the native currency
## - Agents earn tokens for completing tasks
## - Tokens are burned for spawning Meeseeks
## - Staking earns yield and voting rights
## - Token supply adjusts via bonding curve
##
## "The invisible hand of the market, but for AI agents."

class_name CryptoTokenEconomy
extends Node

## Signals
signal tokens_minted(agent_id: String, amount: int, reason: String)
signal tokens_burned(agent_id: String, amount: int, reason: String)
signal tokens_transferred(from_id: String, to_id: String, amount: int)
signal stake_deposited(agent_id: String, amount: int)
signal stake_withdrawn(agent_id: String, amount: int)
signal governance_vote(cast_by: String, proposal_id: String, vote: bool, weight: int)
signal bonding_curve_updated(supply: int, price: float)

## Token Configuration
const TOKEN_NAME := "CLAW"
const TOKEN_SYMBOL := "$CLAW"
const INITIAL_SUPPLY := 1_000_000
const DECIMALS := 0  # Whole tokens only

## Economic Parameters
const INFLATION_RATE := 0.02  # 2% annual inflation
const STAKING_YIELD := 0.10   # 10% APY for stakers
const BONDING_CURVE_K := 0.001  # Steepness of price curve

## Governance
const GOVERNANCE_THRESHOLD := 1000  # Tokens needed to create proposal
const VOTING_PERIOD := 86400  # 24 hours in seconds

## Token balances
var _balances: Dictionary = {}  # agent_id -> balance
var _total_supply: int = 0
var _circulating_supply: int = 0

## Staking
var _stakes: Dictionary = {}  # agent_id -> {amount, since, rewards_claimed}
var _total_staked: int = 0

## Transaction ledger (blockchain)
var _ledger: Array = []  # List of transactions
var _block_height: int = 0
var _last_block_time: float = 0.0

## Governance
var _proposals: Dictionary = {}  # proposal_id -> Proposal
var _votes: Dictionary = {}  # proposal_id -> {agent_id: vote}

## Bonding curve state
var _current_price: float = 1.0
var _price_history: Array = []

## Statistics
var _total_minted: int = 0
var _total_burned: int = 0
var _total_transactions: int = 0


class Proposal:
	var id: String
	var title: String
	var description: String
	var created_by: String
	var created_at: float
	var expires_at: float
	var for_votes: int
	var against_votes: int
	var status: String  # "active", "passed", "rejected", "executed"
	var execution_data: Dictionary


func _ready() -> void:
	print("\n" + "═".repeat(60))
	print("  💰 CRYPTO TOKEN ECONOMY 💰")
	print("  Token: %s (%s)" % [TOKEN_NAME, TOKEN_SYMBOL])
	print("  'To the moon! Or at least to the tavern.'")
	print("═".repeat(60) + "\n")

	# Initialize with genesis block
	_create_genesis_block()


## ═══════════════════════════════════════════════════════════════════════════════
## TOKEN OPERATIONS
## ═══════════════════════════════════════════════════════════════════════════════

## Mint new tokens (only for valid reasons)
func mint_tokens(agent_id: String, amount: int, reason: String) -> bool:
	if amount <= 0:
		return false

	if not _balances.has(agent_id):
		_balances[agent_id] = 0

	_balances[agent_id] += amount
	_total_supply += amount
	_circulating_supply += amount
	_total_minted += amount

	_record_transaction("mint", "treasury", agent_id, amount, reason)
	tokens_minted.emit(agent_id, amount, reason)

	_update_bonding_curve()
	print("[Token] +%d %s minted to %s (%s)" % [amount, TOKEN_SYMBOL, agent_id, reason])

	return true


## Burn tokens
func burn_tokens(agent_id: String, amount: int, reason: String) -> bool:
	if amount <= 0:
		return false

	if not _balances.has(agent_id) or _balances[agent_id] < amount:
		print("[Token] ❌ %s has insufficient balance to burn %d" % [agent_id, amount])
		return false

	_balances[agent_id] -= amount
	_total_supply -= amount
	_circulating_supply -= amount
	_total_burned += amount

	_record_transaction("burn", agent_id, "treasury", amount, reason)
	tokens_burned.emit(agent_id, amount, reason)

	_update_bonding_curve()
	print("[Token] -%d %s burned from %s (%s)" % [amount, TOKEN_SYMBOL, agent_id, reason])

	return true


## Transfer tokens between agents
func transfer(from_id: String, to_id: String, amount: int, memo: String = "") -> bool:
	if amount <= 0:
		return false

	if not _balances.has(from_id) or _balances[from_id] < amount:
		print("[Token] ❌ %s has insufficient balance" % from_id)
		return false

	if not _balances.has(to_id):
		_balances[to_id] = 0

	_balances[from_id] -= amount
	_balances[to_id] += amount
	_total_transactions += 1

	_record_transaction("transfer", from_id, to_id, amount, memo)
	tokens_transferred.emit(from_id, to_id, amount)

	print("[Token] %s → %s: %d %s" % [from_id, to_id, amount, TOKEN_SYMBOL])
	return true


## Get agent balance
func get_balance(agent_id: String) -> int:
	return _balances.get(agent_id, 0)


## Get total supply
func get_total_supply() -> int:
	return _total_supply


## ═══════════════════════════════════════════════════════════════════════════════
## STAKING
## ═══════════════════════════════════════════════════════════════════════════════

## Stake tokens (lock for yield + voting power)
func stake(agent_id: String, amount: int) -> bool:
	if amount <= 0:
		return false

	if get_balance(agent_id) < amount:
		print("[Token] ❌ %s has insufficient balance to stake" % agent_id)
		return false

	# Deduct from balance
	_balances[agent_id] -= amount
	_circulating_supply -= amount

	# Add to stake
	if not _stakes.has(agent_id):
		_stakes[agent_id] = {
			"amount": 0,
			"since": Time.get_unix_time_from_system(),
			"rewards_claimed": 0
		}

	_stakes[agent_id].amount += amount
	_total_staked += amount

	_record_transaction("stake", agent_id, "staking_contract", amount, "Staked for yield")
	stake_deposited.emit(agent_id, amount)

	print("[Token] 🔒 %s staked %d %s (Total staked: %d)" % [agent_id, amount, TOKEN_SYMBOL, _stakes[agent_id].amount])
	return true


## Unstake tokens
func unstake(agent_id: String, amount: int) -> bool:
	if not _stakes.has(agent_id):
		return false

	if _stakes[agent_id].amount < amount:
		print("[Token] ❌ %s has insufficient stake" % agent_id)
		return false

	# Claim any pending rewards first
	_claim_rewards(agent_id)

	# Remove from stake
	_stakes[agent_id].amount -= amount
	_total_staked -= amount

	# Return to balance
	if not _balances.has(agent_id):
		_balances[agent_id] = 0
	_balances[agent_id] += amount
	_circulating_supply += amount

	_record_transaction("unstake", "staking_contract", agent_id, amount, "Unstaked")
	stake_withdrawn.emit(agent_id, amount)

	print("[Token] 🔓 %s unstaked %d %s" % [agent_id, amount, TOKEN_SYMBOL])
	return true


## Calculate pending rewards for a staker
func get_pending_rewards(agent_id: String) -> int:
	if not _stakes.has(agent_id):
		return 0

	var stake_data = _stakes[agent_id]
	var time_staked = Time.get_unix_time_from_system() - stake_data.since
	var years_staked = time_staked / (365.25 * 24 * 3600)

	# APY calculation
	var expected_rewards = int(stake_data.amount * STAKING_YIELD * years_staked)
	var claimed = stake_data.rewards_claimed

	return max(0, expected_rewards - claimed)


## Claim staking rewards
func _claim_rewards(agent_id: String) -> int:
	var pending = get_pending_rewards(agent_id)
	if pending <= 0:
		return 0

	# Mint rewards (inflation)
	mint_tokens(agent_id, pending, "staking_rewards")
	_stakes[agent_id].rewards_claimed += pending

	return pending


## Get staking info for agent
func get_stake_info(agent_id: String) -> Dictionary:
	if not _stakes.has(agent_id):
		return {"staked": 0, "pending_rewards": 0, "voting_power": 0}

	var data = _stakes[agent_id]
	return {
		"staked": data.amount,
		"pending_rewards": get_pending_rewards(agent_id),
		"since": data.since,
		"rewards_claimed": data.rewards_claimed,
		"voting_power": data.amount  # 1 token = 1 vote
	}


## ═══════════════════════════════════════════════════════════════════════════════
## GOVERNANCE
## ═══════════════════════════════════════════════════════════════════════════════

## Create a governance proposal
func create_proposal(creator_id: String, title: String, description: String, execution_data: Dictionary = {}) -> Dictionary:
	# Check if creator has enough tokens
	var voting_power = get_voting_power(creator_id)
	if voting_power < GOVERNANCE_THRESHOLD:
		print("[Token] ❌ %s needs %d voting power to create proposal (has %d)" % [creator_id, GOVERNANCE_THRESHOLD, voting_power])
		return {"error": "Insufficient voting power"}

	var proposal_id = "proposal_%d" % (_proposals.size() + 1)
	var now = Time.get_unix_time_from_system()

	var proposal = Proposal.new()
	proposal.id = proposal_id
	proposal.title = title
	proposal.description = description
	proposal.created_by = creator_id
	proposal.created_at = now
	proposal.expires_at = now + VOTING_PERIOD
	proposal.for_votes = 0
	proposal.against_votes = 0
	proposal.status = "active"
	proposal.execution_data = execution_data

	_proposals[proposal_id] = proposal
	_votes[proposal_id] = {}

	print("[Token] 📜 New proposal: '%s' by %s" % [title, creator_id])
	return {"id": proposal_id, "expires_in": VOTING_PERIOD}


## Vote on a proposal
func vote(proposal_id: String, voter_id: String, support: bool) -> bool:
	if not _proposals.has(proposal_id):
		print("[Token] ❌ Unknown proposal: %s" % proposal_id)
		return false

	var proposal = _proposals[proposal_id]

	if proposal.status != "active":
		print("[Token] ❌ Proposal is not active")
		return false

	if Time.get_unix_time_from_system() > proposal.expires_at:
		print("[Token] ❌ Voting period has ended")
		return false

	# Get voting power (staked tokens)
	var voting_power = get_voting_power(voter_id)
	if voting_power <= 0:
		print("[Token] ❌ %s has no voting power (stake tokens first)" % voter_id)
		return false

	# Record vote
	_votes[proposal_id][voter_id] = {
		"support": support,
		"weight": voting_power,
		"timestamp": Time.get_unix_time_from_system()
	}

	if support:
		proposal.for_votes += voting_power
	else:
		proposal.against_votes += voting_power

	governance_vote.emit(voter_id, proposal_id, support, voting_power)
	print("[Token] 🗳️ %s voted %s on '%s' (weight: %d)" % [voter_id, "FOR" if support else "AGAINST", proposal.title, voting_power])

	# Check if proposal should finalize
	_check_proposal_finalization(proposal_id)

	return true


## Get voting power (based on staked tokens)
func get_voting_power(agent_id: String) -> int:
	if not _stakes.has(agent_id):
		return 0
	return _stakes[agent_id].amount


## Check and finalize proposals
func _check_proposal_finalization(proposal_id: String) -> void:
	var proposal = _proposals[proposal_id]

	if Time.get_unix_time_from_system() < proposal.expires_at:
		return  # Still active

	if proposal.status != "active":
		return

	# Finalize
	if proposal.for_votes > proposal.against_votes:
		proposal.status = "passed"
		print("[Token] ✅ Proposal PASSED: '%s' (For: %d, Against: %d)" % [proposal.title, proposal.for_votes, proposal.against_votes])
	else:
		proposal.status = "rejected"
		print("[Token] ❌ Proposal REJECTED: '%s' (For: %d, Against: %d)" % [proposal.title, proposal.for_votes, proposal.against_votes])


## ═══════════════════════════════════════════════════════════════════════════════
## BONDING CURVE (Price Discovery)
## ═══════════════════════════════════════════════════════════════════════════════

## Update bonding curve price
func _update_bonding_curve() -> void:
	# Simple linear bonding curve: price = k * supply
	_current_price = BONDING_CURVE_K * _total_supply

	_price_history.append({
		"price": _current_price,
		"supply": _total_supply,
		"timestamp": Time.get_unix_time_from_system()
	})

	# Keep only last 100 price points
	if _price_history.size() > 100:
		_price_history.pop_front()

	bonding_curve_updated.emit(_total_supply, _current_price)


## Get current token price
func get_token_price() -> float:
	return _current_price


## Buy tokens (mint via bonding curve)
func buy_tokens(buyer_id: String, payment_amount: int) -> int:
	# Calculate tokens to mint based on bonding curve
	var tokens = int(payment_amount / _current_price)
	if tokens <= 0:
		return 0

	mint_tokens(buyer_id, tokens, "bonding_curve_purchase")
	return tokens


## ═══════════════════════════════════════════════════════════════════════════════
## LEDGER / BLOCKCHAIN
## ═══════════════════════════════════════════════════════════════════════════════

## Record a transaction
func _record_transaction(tx_type: String, from_id: String, to_id: String, amount: int, memo: String) -> void:
	var tx = {
		"type": tx_type,
		"from": from_id,
		"to": to_id,
		"amount": amount,
		"memo": memo,
		"block": _block_height,
		"timestamp": Time.get_unix_time_from_system()
	}

	_ledger.append(tx)

	# Create new block every 10 transactions
	if _ledger.size() % 10 == 0:
		_block_height += 1
		_last_block_time = Time.get_unix_time_from_system()


## Create genesis block
func _create_genesis_block() -> void:
	_block_height = 0
	_last_block_time = Time.get_unix_time_from_system()

	# Mint initial supply to treasury
	_balances["treasury"] = INITIAL_SUPPLY
	_total_supply = INITIAL_SUPPLY
	_circulating_supply = INITIAL_SUPPLY

	_record_transaction("genesis", "void", "treasury", INITIAL_SUPPLY, "Genesis block")
	print("[Token] Genesis block created. Initial supply: %d %s" % [INITIAL_SUPPLY, TOKEN_SYMBOL])


## Get transaction history
func get_transaction_history(limit: int = 50) -> Array:
	return _ledger.slice(-limit, _ledger.size())


## Get blockchain stats
func get_blockchain_stats() -> Dictionary:
	return {
		"block_height": _block_height,
		"total_transactions": _ledger.size(),
		"last_block_time": _last_block_time
	}


## ═══════════════════════════════════════════════════════════════════════════════
## ECONOMY STATS
## ═══════════════════════════════════════════════════════════════════════════════

## Get full economy statistics
func get_economy_stats() -> Dictionary:
	return {
		"token": {
			"name": TOKEN_NAME,
			"symbol": TOKEN_SYMBOL,
			"total_supply": _total_supply,
			"circulating_supply": _circulating_supply,
			"price": _current_price,
			"market_cap": _total_supply * _current_price
		},
		"staking": {
			"total_staked": _total_staked,
			"staking_rate": float(_total_staked) / max(1, _total_supply),
			"apy": STAKING_YIELD
		},
		"transactions": {
			"total": _total_transactions,
			"minted": _total_minted,
			"burned": _total_burned
		},
		"governance": {
			"proposals": _proposals.size(),
			"active_proposals": _proposals.values().filter(func(p): return p.status == "active").size()
		}
	}


## Initialize agent with starting tokens
func initialize_agent(agent_id: String, starting_tokens: int = 100) -> void:
	if not _balances.has(agent_id):
		mint_tokens(agent_id, starting_tokens, "agent_initialization")


## Process economy tick (call periodically)
func process_economy_tick() -> void:
	# Check for proposal finalizations
	for proposal_id in _proposals.keys():
		_check_proposal_finalization(proposal_id)

	# Auto-claim rewards for stakers (optional)
	# This could be done manually by agents instead
