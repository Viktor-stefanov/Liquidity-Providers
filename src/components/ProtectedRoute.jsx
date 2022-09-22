import { Navigate, Outlet } from "react-router-dom";

const ProtectedRoute = ({ isLoggedIn, updateIsLoggedIn }) => {
  console.log(isLoggedIn, updateIsLoggedIn);
  if (!isLoggedIn()) {
    return <Navigate to="/login" state={updateIsLoggedIn} replace />;
  }
  return <Outlet />;
};

export default ProtectedRoute;
