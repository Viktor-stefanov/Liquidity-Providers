import { Route, createBrowserRouter } from "react-router-dom";
import Login from "../components/Login";

const router = createBrowserRouter([
  {
    path: "/",
    element: <Login />,
  },
]);

export default router;
