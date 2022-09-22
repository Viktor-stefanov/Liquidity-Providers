import React from "react";
import { useNavigate } from "react-router-dom";
import Metamask from "../utils/metamask.js";

class Login extends React.Component {
  constructor(props) {
    super(props);
    this.connectWallet = this.connectWallet.bind(this);
  }

  async connectWallet() {
    await Metamask.connectWallet();
    this.props.navigate("/working");
  }

  render() {
    return (
      <>
        <h1>Welcome to UniClone</h1>

        <button onClick={this.connectWallet}>Connect Metamask</button>
      </>
    );
  }
}

export default function WithNavigate(props) {
  let navigate = useNavigate();
  return <Login {...props} navigate={navigate} />;
}
