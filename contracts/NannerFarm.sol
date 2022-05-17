// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

contract NannerShare is Ownable, ERC20, ERC20Burnable {
  constructor() ERC20("TestNannerShare", "TNS") {}
  function mint(address to, uint amount) public virtual onlyOwner {
      _mint(to, amount);
  }
}

contract NannerFarm is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint amount;         // How many LP tokens the user has provided.
        uint rewardDebt;     // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        uint totalStake;
        IERC20 lpToken;       // Address of LP token contract.
        uint allocPoint;      // How many allocation points assigned to this pool. NS to distribute per block.
        uint lastRewardTime;  // Last timestamp that NS distribution occurs.
        uint accNSPerStake;   // Accumulated NS per share, times 1e18. See below.
        uint16 depositFeeBP;  // Deposit fee in basis points
    }

    NannerShare public ns;

    // NANNER NFT
    IERC721 public NANNER = IERC721(0x49a670506377dfBe60bDA8214ac45f6840a92b3f);

    // amount of tokens that == one nanner
    uint public REQUIRED_SHARES = 100 ether;

    // earliest owned nanner
    uint public currentNanner = 0;
    
    // NS tokens created per block.
    uint public nsPerSecond;

    // Dev address.
    address public devAddress;
    // Deposit Fee address
    address public feeAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Added tokens;
    mapping (IERC20 => bool) tokens;

    // Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint public totalAllocPoint = 0;
    // The timestamp when NS mining starts.
    uint public startTime;

    event Add(uint indexed pid, IERC20 lpToken, uint allocPoint, uint16 depositFeeBP);
    event Set(uint indexed pid, uint allocPoint, uint16 depositFeeBP);
    event SetNsPerSecond(uint newNsPerSecond);
    event SetDevAddress(address indexed newDevAddress);
    event SetFeeAddress(address indexed newFeeAddress);
    event Deposit(address indexed user, uint indexed pid, uint amount);
    event Withdraw(address indexed user, uint indexed pid, uint amount);
    event Reinvest(address indexed user, uint indexed pid, uint amount);
    event EmergencyWithdraw(address indexed user, uint indexed pid, uint amount);

    constructor(
        NannerShare _ns,
        address _devAddress,
        address _feeAddress,
        uint _startTime,
        uint _nsPerSecond,
        uint reinvestAllocPoint
    ) {
        require(_devAddress != address(0), 'dev address cant be 0');
        require(_feeAddress != address(0), 'fee address cant be 0');
        require(_nsPerSecond <= 100 ether, 'maximum ns per second is 5');

        ns = _ns;
        devAddress = _devAddress;
        feeAddress = _feeAddress;
        startTime = _startTime;
        nsPerSecond = _nsPerSecond;
        if (startTime == 0) {
          startTime = block.timestamp;
        }

        // add reinvest pool
        poolInfo.push(PoolInfo({
            totalStake: 0,
            lpToken: ns,
            allocPoint: reinvestAllocPoint,
            lastRewardTime: startTime,
            accNSPerStake: 0,
            depositFeeBP: 0
        }));
        totalAllocPoint += reinvestAllocPoint;

        emit Add(0, ns, reinvestAllocPoint, 0);
    }

    function poolLength() external view returns (uint) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(IERC20 lpToken, uint allocPoint, uint16 depositFeeBP, bool withUpdate, uint position) external onlyOwner {
        require(!tokens[lpToken], 'add: token already added');
        require(depositFeeBP <= 500, 'add: maximum deposit fee is 500 (5%)');

        // strictly check pool position for in case of mass initial adding
        require(poolInfo.length == position, 'add: position check failed');

        lpToken.balanceOf(address(this));

        if (withUpdate) {
            massUpdatePools();
        }

        uint lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint += allocPoint;
        poolInfo.push(PoolInfo({
            totalStake:0,
            lpToken: lpToken,
            allocPoint: allocPoint,
            lastRewardTime: lastRewardTime,
            accNSPerStake: 0,
            depositFeeBP: depositFeeBP
        }));
        tokens[lpToken] = true;

        emit Add(position, lpToken, allocPoint, depositFeeBP);
    }

    // Update the given pool's NS allocation point and deposit fee. Can only be called by the owner.
    function set(uint pid, uint allocPoint, uint16 depositFeeBP, bool withUpdate) external onlyOwner {
        require(depositFeeBP <= 500, 'set: maximum deposit fee is 500 (5%)');

        if (withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint - poolInfo[pid].allocPoint + allocPoint;
        poolInfo[pid].allocPoint = allocPoint;
        poolInfo[pid].depositFeeBP = depositFeeBP;

        emit Set(pid, allocPoint, depositFeeBP);
    }

    function setNsPerSecond(uint newNsPerSecond, bool withUpdate) external onlyOwner {

        if (withUpdate) {
            massUpdatePools();
        }

        nsPerSecond = newNsPerSecond;
        emit SetNsPerSecond(newNsPerSecond);
    }

    function setDevAddress(address newDevAddress) external {
        require(msg.sender == devAddress, 'setDevAddress: FORBIDDEN');
        require(newDevAddress != address(0), 'setDevAddress: new dev address cant be 0');
        devAddress = newDevAddress;
        emit SetDevAddress(newDevAddress);
    }

    function setFeeAddress(address newFeeAddress) external {
        require(msg.sender == feeAddress, 'setFeeAddress: FORBIDDEN');
        require(newFeeAddress != address(0), 'setDevAddress: new fee address cant be 0');
        feeAddress = newFeeAddress;
        emit SetFeeAddress(newFeeAddress);
    }

    // View function to see pending NS on frontend.
    function pendingNS(uint pid, address _user) public view returns (uint) {
      PoolInfo storage pool = poolInfo[pid];
      UserInfo storage user = userInfo[pid][_user];

      if (user.amount == 0) {
          return 0;
      }

      uint accNSPerStake = pool.accNSPerStake;
      if (block.timestamp > pool.lastRewardTime && pool.totalStake > 0) {
          uint sec = block.timestamp - pool.lastRewardTime;
          uint nsReward = sec * nsPerSecond * pool.allocPoint / totalAllocPoint;
          accNSPerStake += nsReward * 1e18 / pool.totalStake;
      }

      return user.amount * accNSPerStake / 1e18 - user.rewardDebt;
    }

    // Deposit LP tokens to MasterChef for NS allocation.
    function deposit(uint pid, uint amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];

        updatePool(pid);
        claim(pid);

        if (amount > 0) {
            uint balance = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(msg.sender, address(this), amount);
            amount = pool.lpToken.balanceOf(address(this)) - balance;

            if (pool.depositFeeBP > 0){
                uint depositFee = amount * pool.depositFeeBP / 10000;
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                amount -= depositFee;
            }
            user.amount += amount;
            pool.totalStake += amount;

            emit Deposit(msg.sender, pid, amount);
        }

        user.rewardDebt = user.amount * pool.accNSPerStake / 1e18;
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint pid, uint amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        require(user.amount >= amount, 'withdraw: not good');

        updatePool(pid);
        claim(pid);

        if (amount > 0) {
            user.amount -= amount;
            pool.lpToken.safeTransfer(msg.sender, amount);
        }

        pool.totalStake -= amount;
        user.rewardDebt = user.amount * pool.accNSPerStake / 1e18;
        emit Withdraw(msg.sender, pid, amount);
    }

    function reinvest(uint pid) public nonReentrant {
        _reinvest(pid);
    }

    // Reinvest LP tokens to Reinvest Pool
    function _reinvest(uint pid) internal {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];

        updatePool(pid);

        uint toReinvest = pendingNS(pid, msg.sender);
        if (toReinvest == 0) {
            return;
        }

        if (pid != 0) {
          _reinvest(0);
          user.rewardDebt = user.amount * pool.accNSPerStake / 1e18;
        }

        PoolInfo storage rPool = poolInfo[0];
        UserInfo storage rUser = userInfo[0][msg.sender];

        rUser.amount += toReinvest;
        rPool.totalStake += toReinvest;
        rUser.rewardDebt = rUser.amount * rPool.accNSPerStake / 1e18;

        emit Reinvest(msg.sender, pid, toReinvest);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];

        uint amount = user.amount;
        pool.totalStake -= amount;
        user.amount = 0;
        user.rewardDebt = 0;

        pool.lpToken.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint pid) internal {
        PoolInfo storage pool = poolInfo[pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        if (pool.totalStake == 0 || pool.allocPoint == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        uint sec = block.timestamp - pool.lastRewardTime;
        uint nsReward = sec * nsPerSecond * pool.allocPoint / totalAllocPoint;

        // ns.mint(devAddress, nsReward / 10);
        ns.mint(address(this), nsReward);

        pool.accNSPerStake += nsReward * 1e18 / pool.totalStake;
        pool.lastRewardTime = block.timestamp;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() internal {
        uint length = poolInfo.length;
        for (uint pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function nannersInFarm() public view returns (bool) {
        return NANNER.balanceOf(address(this)) > 0;
    }

    function claim(uint pid) internal {
        uint pending = pendingNS(pid, msg.sender);
        if (pending > REQUIRED_SHARES && nannersInFarm()) {

            while (NANNER.ownerOf(currentNanner) != address(this)) {
                currentNanner +=1; //loop until we find next owned nanner. kinda dangerous. oh well.
            }
            uint nannerToSend = currentNanner;
            currentNanner +=1;

            //burn the shares, send the nanner.
            safeNSTransfer(0x000000000000000000000000000000000000dEaD, pending);
            NANNER.transferFrom(address(this), msg.sender, nannerToSend);
        }
    }

    // Safe ns transfer function, just in case if rounding error causes pool to not have enough NS.
    function safeNSTransfer(address to, uint amount) internal {
        uint nsBal = ns.balanceOf(address(this));
        if (amount > nsBal) {
            ns.transfer(to, nsBal);
        } else {
            ns.transfer(to, amount);
        }
    }

    //admin things
    function setCurrentNanner(uint _nannerNumber) external onlyOwner {
        currentNanner = _nannerNumber;
    }

    function setReqShares(uint _reqShares) external onlyOwner {
        REQUIRED_SHARES = _reqShares;
    }

    function setNannerNFT(address _addy) external onlyOwner {
        NANNER = IERC721(_addy);
    }
}
