const CHAIN={id:677,hex:"0x2A5",name:"BOT Chain ",symbol:"BOT",rpc:"https://rpc.botchain.a",explorer:"https://scan.botchain.a",website:"https://botchain.ai"};
// TODO: replace with your deployed PayBill address
const CONTRACT_ADDRESS="0xD7f9f82998a30bF040796Ae959642e24434b44B0";
const ABI=["function admin() view returns (address)","function addBiller(string name,string category,address wallet) returns (uint256)","function setBillerActive(uint256 id,bool active)","function billerCount() view returns (uint256)","function getBiller(uint256 id) view returns (string,string,address,bool)","function pay(uint256 billerId,string reference) payable","function createSchedule(uint256 billerId,string reference,uint256 intervalDays,uint256 count) payable returns (uint256)","function runSchedule(uint256 id)","function cancelSchedule(uint256 id)","function receiptCount() view returns (uint256)","function getReceipt(uint256 id) view returns (address,uint256,string,uint256,uint256)","function receiptsOf(address a) view returns (uint256[])","function receiptsOfWallet(address a) view returns (uint256[])","function scheduleCount() view returns (uint256)","function getSchedule(uint256 id) view returns (address,uint256,string,uint256)","function getScheduleState(uint256 id) view returns (uint256,uint256,uint256,bool)","function schedulesOf(address a) view returns (uint256[])"];
let signer,account,vault;
const ro=/^0x0+$/.test(CONTRACT_ADDRESS)?null:new ethers.Contract(CONTRACT_ADDRESS,ABI,new ethers.JsonRpcProvider(CHAIN.rpc));
const $=s=>document.querySelector(s);
const short=a=>a.slice(0,6)+"…"+a.slice(-4);
const when=t=>new Date(Number(t)*1000).toLocaleString();
const esc=s=>String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
let tt;function toast(m,err){const t=$("#toast");t.className=err?"err":"";t.innerHTML=m;t.style.display="block";clearTimeout(tt);tt=setTimeout(()=>t.style.display="none",err?6000:5000)}
async function ensureChain(){
  try{await ethereum.request({method:"wallet_switchEthereumChain",params:[{chainId:CHAIN.hex}]})}
  catch(e){if(e.code!==4902&&e.code!==-32603)throw e;
    await ethereum.request({method:"wallet_addEthereumChain",params:[{chainId:CHAIN.hex,chainName:CHAIN.name,nativeCurrency:{name:"BOT",symbol:CHAIN.symbol,decimals:18},rpcUrls:[CHAIN.rpc],blockExplorerUrls:[CHAIN.explorer]}]})}
}
async function connect(silent = false) {
  if (!window.ethereum) {
    if (!silent) toast("Install MetaMask or another EVM wallet.", 1);
    return;
  }
  try {
    const p = new ethers.BrowserProvider(ethereum);

    if (silent) {
      // eth_accounts never triggers a popup
      const accounts = await p.send("eth_accounts", []);
      if (!accounts.length) return; // not approved yet, stop silently
    } else {
      // eth_requestAccounts FIRST — triggers the MetaMask popup
      await p.send("eth_requestAccounts", []);
    }

    // Chain switch only AFTER accounts are available
    await ensureChain();

    signer = await p.getSigner();
    account = await signer.getAddress();
    $("#wbtn").textContent = short(account);

    if (/^0x0+$/.test(CONTRACT_ADDRESS)) return toast("Set CONTRACT_ADDRESS in js/app.js", 1);
    vault = new ethers.Contract(CONTRACT_ADDRESS, ABI, signer);
    document.dispatchEvent(new Event("ready"));
  } catch (e) {
    if (!silent) toast(e.shortMessage || e.message, 1);
  }
}

addEventListener("load", () => {
  $("#wbtn").onclick = () => connect(false);

  // Auto-connect silently on load if previously approved
  if (window.ethereum) {
    connect(true);
    ethereum.on("accountsChanged", accs => accs.length ? connect(true) : location.reload());
    ethereum.on("chainChanged", () => location.reload());
  }
});
async function tx(p,msg){
  try{const t=await p;toast("Transaction sent… waiting for confirmation");await t.wait();
    toast(msg+' ✓ <a target="_blank" href="'+CHAIN.explorer+'/tx/'+t.hash+'">View on explorer</a>');return true}
  catch(e){toast(e.reason||e.shortMessage||e.message,1);return false}
}
function needWallet(el){el.innerHTML='<div class="notice">Connect your wallet to continue.</div>'}
addEventListener("load",()=>{$("#wbtn").onclick=connect;
  if(window.ethereum)ethereum.request({method:"eth_accounts"}).then(a=>a.length&&connect())});

const bot=w=>ethers.formatEther(w)+" BOT";
const ICON={"Electricity":"💡","Water":"💧","Internet":"🌐","Airtime & data":"📱","TV subscription":"📺","Education":"🎓","Other":"🧾"};
const _b={};async function billerOf(id){if(!_b[id]){const b=await ro.getBiller(id);_b[id]={name:b[0],cat:b[1],wallet:b[2],active:b[3]}}return _b[id]}
