import React from "react";
import { Routes, Route } from "react-router-dom";
import Pool from "./components/Pool";
import Pairs from "./components/Pairs";
import Login from "./components/Login";
import Header from "./components/Header";
import AuthProvider from "./components/AuthProvider";
import ProtectedRoute from "./components/ProtectedRoute";

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route element={<ProtectedRoute />}>
          <Route path="/" />
        </Route>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<Header />}>
          <Route path="/pool" element={<Pool />} />
          <Route path="/pairs" element={<Pairs />} />
        </Route>
      </Routes>
    </AuthProvider>
  );
}
