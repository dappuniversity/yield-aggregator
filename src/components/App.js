import React, { Component } from 'react';
import logo from '../logo.png';
import './App.css';

class App extends Component {
	render() {
		return (
			<div>
				<nav className="navbar navbar-dark fixed-top bg-dark flex-md-nowrap p-0 shadow">
					<a
						className="navbar-brand col-sm-3 col-md-2 mr-0 mx-3"
						href="http://www.dappuniversity.com/bootcamp"
						target="_blank"
						rel="noopener noreferrer"
					>
						Dapp University
					</a>
				</nav>
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
								<button>Deposit</button>
								<button>Rebalance</button>
								<button>Withdraw</button>
							</div>
							<div className="col user-stats">
								<p>Current Wallet Balance (DAI): 0</p>
								<p>Aggregator Balance (DAI): 0</p>
								<p>Active Protocol: UNDEFINED</p>
							</div>
						</div>
					</main>

				</div>
			</div>
		);
	}
}

export default App;
