const { ethers } = require("ethers");
const abi = new ethers.utils.Interface(
    [
      "function dispatchMessage(address to, uint256 fee, uint256 deadline, uint256 nonce, bytes calldata _data) external payable"
    ]
  );
  // receiver
  let to = '0x4444444444444444444444444444444444444444'
  // 1 ETH
  let value = 'de0b6b3a7640000'
  // no fee
  let fee = 0
  // in seconds since UNIX Epoch until invalid - just make this large if y d care
  let deadline = '0xffffffffffffffff'
  // some random or unique value
  let nonce = '0xf00b4'
  // empty calldata
  let data = '0x'
  
  let input = abi.encodeFunctionData('dispatchMessage', [to, fee, deadline, nonce, data]);
  // to l1 bridge
  tx = { to: '0x936a70c0b28532aa22240dce21f89a8399d6ac60', value, data }
  console.log(input)
//   WScript.StdOut.WriteLine(input);

//   process.argv.forEach(function (val, index, array) {
//     console.log(index + ': ' + val);
//   });

// var a = process.argv[2];
// console.log(a);