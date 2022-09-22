import React from "react";
import { RouterProvider } from "react-router-dom";
import router from "./router/router";

export default class App extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return (
      <React.StrictMode>
        <RouterProvider router={router} />
      </React.StrictMode>
    );
  }
}
