### ==================================
###          HYPERION TESTS
### ==================================

%lang starknet

### ========== dependencies ==========

# starkware-std
from starkware.cairo.common.cairo_builtins import HashBuiltin

# openzeppelin
from src.openzeppelin.token.erc20.IERC20 import IERC20
from src.openzeppelin.token.erc20.library import ERC20

from src.interfaces.IHyperion import IHyperion

### =========== constants ============

const USER = 'user'
const TOKEN_NAME_A = 'ajax'
const TOKEN_NAME_B = 'shryke'
const TOKEN_NAME_C = 'voyage'
const SYMBOL_A = 'AJX'
const SYMBOL_B = 'SHRK'
const SYMBOL_C = 'VOY'
const DECIMALS = 18
const SUPPLY_HI = 100000
const SUPPLY_LO = 0
const ARR_LEN = 2

### ============= setup ==============

@external
func __setup__{syscall_ptr : felt*}():
    alloc_locals
    
    tempvar token_a
    tempvar token_b
    tempvar token_c
    tempvar hyperion
    tempvar hyperion_multi_coin
    %{
        ids.token_a = deploy_contract(
            "./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", 
            [ids.TOKEN_NAME_A, ids.SYMBOL_A, ids.DECIMALS, ids.SUPPLY_LO, ids.SUPPLY_HI, ids.USER]).contract_address
        context.token_a = ids.token_a

        ids.token_b = deploy_contract(
            "./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", 
            [ids.TOKEN_NAME_B, ids.SYMBOL_B, ids.DECIMALS, ids.SUPPLY_LO, ids.SUPPLY_HI, ids.USER]).contract_address
        context.token_b = ids.token_b
       
        ids.token_c = deploy_contract(
            "./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo",  
            [ids.TOKEN_NAME_C, ids.SYMBOL_C, ids.DECIMALS, ids.SUPPLY_LO, ids.SUPPLY_HI, ids.USER]).contract_address
        context.token_c = ids.token_c

        ids.hyperion = deploy_contract(
            "./src/hyperion.cairo",
            [ids.ARR_LEN, ids.token_a, ids.token_b, 100]).contract_address
        context.hyperion = ids.hyperion
        
        ids.hyperion_multi_coin = deploy_contract(
            "./src/hyperion.cairo",
            [ids.ARR_LEN + 1, ids.token_a, ids.token_b, ids.token_c, 100]).contract_address
        context.hyperion_multi_coin = ids.hyperion_multi_coin

    %}

    return()
end

@external
func test_get_token{
        syscall_ptr : felt*,
        #pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}():
    alloc_locals

    let (hyperion) = hyperion_instance.deployed()
    let (token_a) = token_a_instance.deployed()
    let (token_b) = token_b_instance.deployed()
    
    let (address_b) = IHyperion.get_token(hyperion, token_index=2)
    assert token_b = address_b

    let (address_a) = IHyperion.get_token(hyperion, token_index=1)
    assert token_a = address_a

    return()
end

@external
func test_D{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}():
    alloc_locals

    let (hyperion) = hyperion_instance.deployed()
    let (token_a) = token_a_instance.deployed()
    let (token_b) = token_b_instance.deployed()
    
    let (D) = IHyperion.view_D(hyperion)
    assert D = 2000
    return()
end

@external
func test_A{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}():
    alloc_locals

    let (hyperion) = hyperion_instance.deployed()
    let (token_a) = token_a_instance.deployed()
    let (token_b) = token_b_instance.deployed()
    
    let (A) = IHyperion.view_A(hyperion)
    assert A = 10000
    return()
end

@external
func test_exchange{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}():
    alloc_locals

    let (hyperion) = hyperion_instance.deployed()
    let (token_a) = token_a_instance.deployed()
    let (token_b) = token_b_instance.deployed()
    
    let (y, i_balance, j_balance, dy) = IHyperion.exchange(hyperion, 1, 2, 100)
    
    assert y = 2024
    assert i_balance = 1100
    assert j_balance = 924
    assert dy = 76

    # for building intuition

    let (y_1, i_1, j_1, dy_1) = IHyperion.exchange(hyperion, 1, 2, 300)
    
    # pool balance 
    assert y_1 = 2015
    # token_a balance
    assert i_1 = 1400
    # token_b balance
    assert j_1 = 615
    # amount recieved
    assert dy_1 = 309

    let (y_2, j_2, i_2, dy_2) = IHyperion.exchange(hyperion, 2, 1, 500)

    # pool balance
    assert y_2 = 2006
    # token_b balance
    assert j_2 = 1115
    # token_a balance
    assert i_2 = 891
    # amount recieved
    assert dy_2 = 509
    
    let (y_3, j_3, i_3, dy_3) = IHyperion.exchange(hyperion, 2, 1, 200)

    # pool balance
    assert y_3 = 1997
    # token_b balance
    assert j_3 = 1315
    # token_a balance
    assert i_3 = 682
    # amount recieved
    assert dy_3 = 209
    
    return()
end

@external
func test_multi_coin{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}():
    alloc_locals

    let (hyperion_multi_coin) = hyperion_multi_coin_instance.deployed()
    let (token_a) = token_a_instance.deployed()
    let (token_b) = token_b_instance.deployed()
    let (token_c) = token_c_instance.deployed()

    let (y, i_balance, j_balance, dy) = IHyperion.exchange(hyperion_multi_coin, 1, 3, 100)
    
    assert y = 0
    assert i_balance = 0
    assert j_balance = 0
    assert dy = 0

    return()
end

### ======== token-contracts =========

namespace hyperion_instance:
    func deployed() -> (contract : felt):
        tempvar hyperion
        %{ ids.hyperion = context.hyperion %}
        return (contract=hyperion)
    end
            
end

namespace hyperion_multi_coin_instance:
    func deployed() -> (contract : felt):
        tempvar hyperion_multi_coin
        %{ ids.hyperion_multi_coin = context.hyperion_multi_coin %}
        return (contract=hyperion_multi_coin)
    end

end

namespace token_a_instance:
    func deployed() -> (token_contract : felt):
        tempvar token_a
        %{ ids.token_a = context.token_a %}
        return (token_contract=token_a)
    end
            
end

namespace token_b_instance:
    func deployed() -> (token_contract : felt):
        tempvar token_b
        %{ ids.token_b = context.token_b %}
        return (token_contract=token_b)
    end

end

namespace token_c_instance:
    func deployed() -> (token_contract : felt):
        tempvar token_c
        %{ ids.token_c = context.token_c %}
        return (token_contract=token_c)
    end

end

