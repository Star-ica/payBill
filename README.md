# PayBill
1. Deploy `contract/PayBill.sol` on BOT Chain. The deployer becomes admin.
2. Set `CONTRACT_ADDRESS` in `js/app.js`.
3. Serve the folder (e.g. VS Code Live Server) and open `index.html`.
Flow: admin registers billers -> users pay with an account reference and get an on-chain receipt. Recurring: deposit total up front; payments release when due (anyone can trigger `runSchedule`); payer can cancel for a refund of the remainder.
Not audited; test on a testnet first.
# payBill
