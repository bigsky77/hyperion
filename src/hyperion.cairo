### ==================================
###              HYPERION
### ==================================

%lang starknet

### ========== dependencies ==========

# cairo std-lib
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem, assert_not_equal, assert_not_zero, assert_lt 
from starkware.cairo.common.uint256 import Uint256, uint256_lt

# starknet std-lb
from starkware.starknet.common.syscalls import get_block_timestamp, get_contract_address, get_caller_address

# openzeppelin std-lib
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.token.erc20.library import ERC20
from openzeppelin.access.ownable.library import Ownable 

from src.utils.structs import _A

### ============= const ==============

const PRECISION = 100
const POOL_NAME = 'hyperion' # set at compile time
const POOL_SYMBOL = 'HYPE' # set at compile time
const DECIMALS = 18

### =========== interface ============

@contract_interface
namespace IHyperion: 
    func get_token(token_index : felt) -> (token_address : felt):
    end

    func exchange(i : felt, j : felt, _dx : felt) -> (pool_balance : felt, i_balance : felt, j_balance : felt, dy : felt):
    end

    func mint():
    end

    func burn():
    end

    func view_D() -> (res : felt):
    end

    func view_A() -> (res : felt):
    end

end

### ======= storage variables ========

@storage_var
func n_tokens() -> (n_tokens : felt):
end

@storage_var
func tokens(token_index : felt) -> (token_address : felt):
end

@storage_var
func token_balance(token_index :  felt) -> (balance : felt):
end

@storage_var
func pool_token() -> (address : felt):
end

@storage_var 
func _A_() -> (a : _A):
end

### ============= events =============

@event
func liquidity_added(pool_balance : felt, amount_minted : felt, blocktime : felt):
end

@event
func liquidity_removed(pool_balance : felt, amount_in : felt, amount_out : felt, blocktime : felt):
end

@event
func swap(pool_balance : felt, amount_in : felt, amount_out : felt, blocktime : felt):
end

### ========== constructor ===========

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(arr_len : felt, arr : felt*, A : felt):
    
    n_tokens.write(arr_len)
    set_tokens(arr_len, arr)

    # placeholder for testing purposes only 
    init_pool(arr_len)

    let (time) = get_block_timestamp()
    let a = _A(
        precision=PRECISION,
        initial_a=A * PRECISION,
        future_a=A * PRECISION,
        initial_a_time=time,
        future_a_time=time,
    )

    _A_.write(a)

    let (address_this) = get_contract_address()
    ERC20.initializer(POOL_NAME, POOL_SYMBOL, DECIMALS)
    Ownable.initializer(owner=address_this)

    return()
end

### ============= views ==============

@view
func get_token{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(token_index : felt) -> (token_address : felt):
    alloc_locals
    let (token_address) = tokens.read(token_index)
    return(token_address)
end

@view 
func get_xp{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}() -> (res_len : felt, res : felt*):
    alloc_locals
    
    let (n) = n_tokens.read()
    let (arr) = alloc()
    assert [arr + 0] = 0
    let (res) = _xp(n, arr)
    return(n, res)
end

@view
func view_D{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}() -> (D : felt):
    alloc_locals

    let (xp_len, _xp) = get_xp()
    let (A) = get_A()

    let (res) = get_D(A, xp_len, _xp)
    return(res)
end

@view
func view_A{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}() -> (A : felt):
    alloc_locals
    let (A) = get_A()
    return(A)
end

### ============ exchange ============

# param: i   index of the token to send
# param: j   index of the token to recieve
# param: _dx amount of the token to send
@external
func exchange{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(i : felt, j : felt, _dx : felt) -> (pool_balance : felt, i_balance : felt, j_balance : felt, dy : felt):
    alloc_locals

    let (arr) = alloc()
    # need to set first value of array to zero for arr_sum to work
    assert [arr + 0] = 0
    let (arr_len) = n_tokens.read()
    let (old_balances) = _xp(arr_len, arr) 
  
    let x = old_balances[i] + _dx
    let (y) = get_y(i, j, x, arr_len, old_balances) 
    
    let dy = old_balances[j] - y - 1 

    # change balances 
    token_balance.write(i, x)
    token_balance.write(j, old_balances[j] - dy)
    
    let (i_balance) = token_balance.read(i)
    let (j_balance) = token_balance.read(j)
    let pool_balance = i_balance + j_balance 

    return(pool_balance, i_balance, j_balance, dy)
end

### ============== mint ==============

@external 
func mint{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(amounts_len : felt, amounts : felt*, tokens_len : felt, tokens : felt*,   ) -> (res : felt):
    alloc_locals

    let(address_this) = get_contract_address()
    let (user_address) = get_caller_address()

    let (a) = get_A()
    local amp = a
    let (old_balances) = _xp(tokens_len, tokens)
    let (D0) = get_D(amp, tokens_len, tokens)

    let (new_balance) = update_balances(amounts_len, amounts)

    let (D1) = get_D(amp, amounts_len, new_balance)
    
    assert_lt(D0, D1)
    
    let (total_supply) = IERC20.totalSupply(address_this)
    
    # only execute loop if liquidity has alread been minted
    let (x) = uint256_lt(Uint256(0, 0), total_supply)
    if x != 0:
        let (n) = n_tokens.read()
        ideal_balance_loop(n, old_balances, D1, D0) 
    end

    # need to calculate D2 - placeholder for now
    tempvar mint_amount = total_supply * (D1 - D0) / D0
    ERC20._mint(user_address, mint_amount)
    
    return('todo')
end

# in place for when fees are implimented
func ideal_balance_loop{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(balances_len : felt, balances : felt*, D1, D0) -> (ideal_balance : felt): 
    let (ideal_balance) = D1 * balances[balances_len] / D0 
    return(ideal_balance)
end

func update_balances{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(amounts_len : felt, amounts : felt*) -> (arr : felt*):
    alloc_locals

    if amounts_len == 0:
        return(amounts)
    end

    let _amount = amounts[amounts_len]
    token_balance.write(amounts_len, _amount)
    
    let (res) = update_balances(amounts_len - 1, amounts)
    return(res)
end

### =============== _y ===============

func get_y{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(i : felt, j : felt, _dx : felt, xp_len : felt, _xp : felt*) -> (y : felt):
    alloc_locals

    assert_not_equal(i, j)
    assert_not_zero(i)
    assert_not_zero(j)
 
    let (n) = n_tokens.read()
    let (A) = get_A()
    let (a : _A) = _A_.read()
    let (D) = get_D(A , n, _xp)
    
    let Ann = A * n
    
    let (_s) = array_sum(xp_len + 1, _xp)
    tempvar S = _s + _dx - _xp[i] - _xp[j]
    
    let (_c_) = find_C(xp_len, _xp, D, D)
    
    # a_div_ann = a.precision / (ann * a) 
    let (_, a_div_ann) = unsigned_div_rem(a.precision, (Ann * n))
    
    # bc a.precision / (Ann * n) will always be a fraction   
    let (c, _) = unsigned_div_rem((_c_ * D), a_div_ann)
    let (_, _a_rem) = unsigned_div_rem(a.precision, Ann) 
    # same thing here - divide by the remainder
    let (d_b, _) = unsigned_div_rem(D, _a_rem)
    tempvar b = S + d_b

    tempvar count = 255
    tempvar _y = D

    let (y) = y_loop(count, D, c, b, _y)
    
    return(y)
end

func y_loop{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(count : felt, D : felt, c : felt, b : felt, y : felt) -> (res : felt):
    alloc_locals

    # should never reach zero
    if count == 0:
        return(0)
    end

    let y_prev = y
    let (_new, _) = unsigned_div_rem((y * y + c), (2 * y + b - D))
    local y_new = _new 

    # y_new > y_prev
    let (x) = is_le(y_prev, y_new - 1) 
        if x != 0:
           
            let (z) = is_le(y_new - y_prev, 1)
                if z != 0: 
                    return(y_new)
                end
            end    
             
    let (a) = is_le(y_prev - y_new, 1)
        if a != 0:
            return(y_new)
        end 

    let (res) = y_loop(count - 1, D, c, b, y_new)
    return(res)
end

func find_C{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(xp_len : felt, _xp : felt*, D : felt, C : felt) -> (res : felt):
    alloc_locals

    let (n) = n_tokens.read()

    if xp_len == 0:
        return(C)
    end
    
    let (d_div, _) = unsigned_div_rem(D, (_xp[xp_len] * n))
    let c = C * d_div
    let (res) = find_C(xp_len - 1, _xp, D, c)
    return(res)
end

### =============== _D ===============

func get_D{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(A : felt, xp_len : felt, _xp : felt*) -> (D : felt):
    alloc_locals 

    let (S) =  array_sum(xp_len + 1, _xp)

    if S == 0:
        return(0)
    end

    let D = S
    let Ann = A * xp_len
    let count = 255

    let (D_P) = D_P_loop(D, D, xp_len, _xp)
    let (D) = D_loop(count, S, D, Ann, xp_len, _xp, D_P)

    return(D)
end

func D_loop{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(count : felt, S : felt, D_prev : felt, Ann : felt, xp_len : felt, _xp : felt*, D_P : felt) -> (res : felt):
    alloc_locals
    let (a) = _A_.read() 
    let (n) = n_tokens.read()
    # should never reach 0 
    if count == 0:
        return(0)
    end
    
    # weird naming convention here - need to clean up 
    let (t, _) = unsigned_div_rem(S, a.precision)
    let (m, _) = unsigned_div_rem(D_prev, a.precision)
    tempvar numerator = (Ann * t + D_P * n) * D_prev
    tempvar denominator = ((Ann - a.precision) * m + (n + 1) * D_P)

    let (_d, _) = unsigned_div_rem(numerator, denominator)
    local D_new = _d

    # D_new > D
    let (y) = is_le(D_prev, D_new - 1)
        if y != 0:
            let (z) = is_le(D_new - D_prev, 1)
                if z != 0:
                    return(D_new)
                end
        end

    let (x) = is_le(D_prev - D_new, 1)
        if x != 0:
            return(D_new)
        end

    let (res) = D_loop(count - 1, S, D_new, Ann, xp_len, _xp, D_P)
    return(res)
end

func D_P_loop{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(D_P : felt, D : felt, xp_len : felt, _xp : felt*) -> (D_P_ : felt):
    alloc_locals

    let (n) = n_tokens.read()
    if xp_len == 0:
        return(D_P)
    end

    let (x, _) = unsigned_div_rem(D, (_xp[xp_len] * n))
    let res = D_P * x 
    let (D_P_) = D_P_loop(res, D, xp_len - 1, _xp)
    return(D_P_)
end

### ==============  A  ===============

func get_A{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}() -> (A : felt):
    alloc_locals

    let (_a) = _A_.read()
    
    let t1 = _a.future_a_time
    let A1 = _a.future_a

    let (block_time_stamp) = get_block_timestamp()

        # if blocktime < t1
        let (x) = is_le(block_time_stamp, t1 - 1)
        if x != 0: 
            let A0 = _a.initial_a
            let t0 = _a.initial_a_time
        
            # assert A1 > A0
            let (y) = is_le(A0, A1 - 1)
            if y != 0:
                let (A, _) = unsigned_div_rem((A0 + (A1 - A0) * (block_time_stamp - t0)), (t1 - t0))
                return(A)
            else:
                let (A, _) = unsigned_div_rem((A0 - (A0 - A1) * (block_time_stamp - t0)), (t1 - t0))
                return(A)
            end 
        end

    return(A1)
end

### ============= utils ==============

func set_tokens{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(arr_len : felt, arr : felt*):
    alloc_locals

    if arr_len == 0:
        return()
    end

    tokens.write(arr_len, arr[arr_len - 1])
    set_tokens(arr_len - 1, arr)
    return()
end

func _xp{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(n : felt, arr : felt*) -> (res : felt*):
    alloc_locals
    
    if n == 0:
        return(arr)
    end

    let (x) = token_balance.read(n)
    assert arr[n] = x 

    _xp(n - 1, arr)

    # should never reach here
    return(arr)
end

func array_sum{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(arr_len : felt, arr : felt*) -> (sum : felt): 
    if arr_len == 0: 
        return(0)
    end

    let (sum_of_rest) = array_sum(arr_len - 1, arr + 1)
    return(sum=[arr] + sum_of_rest)
end

# until we build out the pool this will set the initial state for testing
func init_pool{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(n : felt):
    if n == 0:
        return()
    end

    token_balance.write(n, 1000)
    init_pool(n - 1)
    return()
end



