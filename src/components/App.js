import Web3 from 'web3'

import React, { Component } from 'react';
import logo from '../logo.png';
import './App.css';

import Aggregator from '../abis/Aggregator.json'
import DAI_ABI from '../helpers/dai-abi.json'

// Import components
import NavBar from './Navbar'

class App extends Component {

	constructor() {
		super();
		this.state = {
			web3: null,
			aggregator: null,
			dai: null,
			cDAI: "0x5d3a536e4d6dbd6114cc1ead35777bab948e3643", // Address of Compound's cDAI
			aaveLendingPool: "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9", // Address of aaveLendingPool
			account: "0x0",
			walletBalance: "0",
			aggregatorBalance: "0",
			activeProtocol: "None",
			amountToDeposit: "0",
			loading: true
		};

		// Binding methods here
		this.depositHandler = this.depositHandler.bind(this);

	}

	componentWillMount() {
		this.loadWeb3()
	}

	async loadWeb3() {
		if (window.ethereum) {

			window.web3 = new Web3(window.ethereum)
			await window.ethereum.enable()

			this.loadBlockchainData(this.props.dispatch)

		} else if (window.web3) {
			window.web3 = new Web3(window.web3.currentProvider)
		} else {
			window.alert('Non-ethereum browser detected.')
		}
	}

	async loadBlockchainData(dispatch) {
		const web3 = new Web3(window.ethereum)
		this.setState({ web3 })

		const networkId = await web3.eth.net.getId()

		const accounts = await web3.eth.getAccounts()
		this.setState({ account: accounts[0] })

		const aggregator = new web3.eth.Contract(Aggregator.abi, Aggregator.networks[networkId].address)

		if (!aggregator) {
			window.alert('Aggregator smart contract not detected on the current network. Please select another network with Metamask.')
			return
		}

		this.setState({ aggregator })

		const DAI_ADDRESS = '0x6b175474e89094c44da98b954eedeac495271d0f'
		const dai = new web3.eth.Contract(DAI_ABI, DAI_ADDRESS)

		this.setState({ dai })

		await this.loadAccountInfo()

	}

	async loadAccountInfo() {

		let walletBalance = await this.state.dai.methods.balanceOf(this.state.account).call()
		let aggregatorBalance = await this.state.aggregator.methods.balanceOf(this.state.account).call()
		let activeProtocol = await this.state.aggregator.methods.balanceWhere(this.state.account).call()

		walletBalance = this.state.web3.utils.fromWei(walletBalance, 'ether')
		aggregatorBalance = this.state.web3.utils.fromWei(aggregatorBalance, 'ether')

		this.setState({ walletBalance })
		this.setState({ aggregatorBalance })

		if (activeProtocol === this.state.cDAI) {
			this.setState({ activeProtocol: "Compound" })
		} else if (activeProtocol === this.state.aaveLendingPool) {
			this.setState({ activeProtocol: "Aave" })
		} else {
			this.setState({ activeProtocol: "None" })
		}
	}

	async depositHandler() {
		if (this.state.walletBalance == 0) {
			window.alert('No funds in wallet')
			return
		}

		if (this.state.amountToDeposit <= 0) {
			window.alert('Cannot be 0 or negative')
			return
		}

		const amount = this.state.web3.utils.toWei(this.state.amountToDeposit.toString(), 'ether')

		this.state.dai.methods.approve(this.state.aggregator._address, amount).send({ from: this.state.account })
			.on('transactionHash', () => {
				this.state.aggregator.methods.deposit(
					this.state.dai._address,
					this.state.cDAI,
					this.state.aaveLendingPool,
					amount
				).send({ from: this.state.account })
					.on('transactionHash', () => {
						this.loadAccountInfo()
					})
			})
	}

	render() {
		return (
			<div>
				<NavBar account={this.state.account} />
				<div className="container-fluid">
					<main role="main" className="col-lg-12 text-center">
						<div className="row">
							<div className="col">
								<h1 className="my-5">Yield Aggregator</h1>
								<a
									href="http://www.dappuniversity.com/bootcamp"
									target="_blank"
									rel="noopener noreferrer"
								>
									<img src={logo} className="App-logo" alt="logo" />
								</a>
							</div>
						</div>
						<div className="row content">
							<div className="col user-controls">
								<form onSubmit={(e) => {
									e.preventDefault()
									this.depositHandler()
								}}>
									<input type="number" placeholder="Amount" onChange={(e) => this.setState({ amountToDeposit: e.target.value })} />
									<button type="submit">Deposit</button>
								</form>
								<button>Rebalance</button>
								<button>Withdraw</button>
							</div>
							<div className="col user-stats">
								<p>Current Wallet Balance (DAI): {this.state.walletBalance}</p>
								<p>Aggregator Balance (DAI): {this.state.aggregatorBalance}</p>
								<p>Active Protocol: {this.state.activeProtocol}</p>
							</div>
						</div>
					</main>

				</div>
			</div>
		);
	}
}

export default App;
