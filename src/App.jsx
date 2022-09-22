import React from "react";
import { Routes, Route } from "react-router-dom";
import Pairs from "./components/Pairs";
import Login from "./components/Login";
import AuthProvider, { useAuth } from "./components/AuthProvider";
import ProtectedRoute from "./components/ProtectedRoute";

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/" element={<Pairs />} />
        <Route path="/login" element={<Login />} />
      </Routes>
    </AuthProvider>
  );
}
