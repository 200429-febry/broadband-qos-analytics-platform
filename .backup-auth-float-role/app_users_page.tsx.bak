"use client";

import { useEffect, useMemo, useState } from "react";

interface User {
  id: number;
  username: string;
  email?: string;
  role: string;
  created_at: string;
  photo_url?: string;
  cover_url?: string;
}

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [pendingRoles, setPendingRoles] = useState<Record<number, string>>({});
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const [search, setSearch] = useState("");

  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState("Viewer");
  const [loading, setLoading] = useState(false);
  const [uploadingUserId, setUploadingUserId] = useState<number | null>(null);

  const fetchUsers = async () => {
    const token = (localStorage.getItem("access_token") || localStorage.getItem("token"));

    try {
      const response = await fetch(`${API_URL}/api/users`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      const data = await response.json();

      if (!Array.isArray(data)) {
        setError(data.error || "Unable to load users");
        return;
      }

      setUsers(data);
      setError("");
    } catch {
      setError("Failed to connect to user service");
    }
  };

  const createUser = async () => {
    setLoading(true);
    setError("");
    setMessage("");

    const token = (localStorage.getItem("access_token") || localStorage.getItem("token"));

    try {
      const response = await fetch(`${API_URL}/api/users`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          username,
          password,
          role,
        }),
      });

      const data = await response.json();

      if (data.error) {
        setError(data.error);
        return;
      }

      setMessage("User created successfully.");
      setUsername("");
      setPassword("");
      setRole("Viewer");

      fetchUsers();
    } catch {
      setError("Failed to create user");
    } finally {
      setLoading(false);
    }
  };

  const uploadUserAssets = async (
    userId: number,
    photo?: File | null,
    cover?: File | null
  ) => {
    const formData = new FormData();

    if (photo) formData.append("photo", photo);
    if (cover) formData.append("cover", cover);

    setUploadingUserId(userId);
    setError("");
    setMessage("");

    try {
      const response = await fetch(`${API_URL}/api/users/${userId}/assets`, {
        method: "POST",
        body: formData,
      });

      const data = await response.json();

      if (data.error) {
        setError(data.error);
        return;
      }

      const currentUser = JSON.parse(localStorage.getItem("user") || "{}");

      if (
        String(currentUser.id) === String(userId) ||
        currentUser.username === users.find((u) => u.id === userId)?.username
      ) {
        localStorage.setItem(
          "user",
          JSON.stringify({
            ...currentUser,
            photo_url: data.photo_url || currentUser.photo_url,
            cover_url: data.cover_url || currentUser.cover_url,
          })
        );
      }

      const version = Date.now();

      setUsers((prev) =>
        prev.map((user) =>
          user.id === userId
            ? {
                ...user,
                photo_url: data.photo_url
                  ? `${data.photo_url}?v=${version}`
                  : user.photo_url,
                cover_url: data.cover_url
                  ? `${data.cover_url}?v=${version}`
                  : user.cover_url,
              }
            : user
        )
      );

      setMessage("User image updated successfully.");
    } catch {
      setError("Failed to upload user image");
    } finally {
      setUploadingUserId(null);
    }
  };

  const deleteUser = async (userId: number) => {
    if (!confirm("Delete this user?")) return;

    const token = (localStorage.getItem("access_token") || localStorage.getItem("token"));

    try {
      const response = await fetch(
        `${API_URL}/api/users/${userId}`,
        {
          method: "DELETE",
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      );

      const data = await response.json();

      if (data.error) {
        setError(data.error);
        return;
      }

      setMessage("User deleted successfully.");
      fetchUsers();
    } catch {
      setError("Failed to delete user");
    }
  };

  const updateRole = async (
    userId: number,
    username: string,
    newRole: string
  ) => {
    const token = (localStorage.getItem("access_token") || localStorage.getItem("token"));

    try {
      const response = await fetch(
        `${API_URL}/api/users/${userId}`,
        {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({
            username,
            role: newRole,
          }),
        }
      );

      const data = await response.json();

      if (data.error) {
        setError(data.error);
        return;
      }

      setMessage("Role updated successfully.");
      try {
        const stored = localStorage.getItem("user");
        if (stored) {
          const parsed = JSON.parse(stored);
          if (Number(parsed.id) === Number(userId)) {
            parsed.role = newRole;
            localStorage.setItem("user", JSON.stringify(parsed));
          }
        }
      } catch {
        // ignore localStorage sync error
      }


      setUsers((prev) =>
        prev.map((user) =>
          user.id === userId ? { ...user, role: newRole } : user
        )
      );

      setPendingRoles((prev) => {
        const copy = { ...prev };
        delete copy[userId];
        return copy;
      });

      const storedUser = localStorage.getItem("user");
      if (storedUser) {
        try {
          const parsedUser = JSON.parse(storedUser);
          if (Number(parsedUser.id) === Number(userId)) {
            localStorage.setItem(
              "user",
              JSON.stringify({
                ...parsedUser,
                role: newRole,
              })
            );
            window.dispatchEvent(new Event("storage"));
          }
        } catch {
          // ignore invalid localStorage data
        }
      }

      fetchUsers();
    } catch {
      setError("Failed to update role");
    }
  };

  const filteredUsers = useMemo(() => {
    return users.filter((u) =>
      u.username.toLowerCase().includes(search.toLowerCase())
    );
  }, [users, search]);

  useEffect(() => {
    fetchUsers();
  }, []);

  const badgeColor = (role: string) => {
    if (role === "Admin") {
      return "bg-red-500/10 text-red-400 border-red-500/30";
    }

    if (role === "Engineer") {
      return "bg-cyan-500/10 text-cyan-400 border-cyan-500/30";
    }

    return "bg-emerald-500/10 text-emerald-400 border-emerald-500/30";
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-4xl font-bold text-white">
          User Management
        </h1>
        <p className="text-gray-400">
          Manage platform users, roles, and permissions.
        </p>
      </div>

      <div className="bg-[#0f172a] rounded-2xl border border-slate-700 p-6">
        <h2 className="text-xl font-semibold mb-4 text-white">
          Create New User
        </h2>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <input
            className="rounded-lg bg-slate-950 border border-slate-700 px-4 py-3 text-white"
            placeholder="Username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />

          <input
            className="rounded-lg bg-slate-950 border border-slate-700 px-4 py-3 text-white"
            placeholder="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />

          <select
            className="rounded-lg bg-slate-950 border border-slate-700 px-4 py-3 text-white"
            value={role}
            onChange={(e) => setRole(e.target.value)}
          >
            <option>Admin</option>
            <option>Engineer</option>
            <option>Viewer</option>
          </select>

          <button
            onClick={createUser}
            disabled={loading}
            className="rounded-lg bg-emerald-600 px-4 py-3 text-white font-semibold hover:bg-emerald-500"
          >
            {loading ? "Creating..." : "Create User"}
          </button>
        </div>

        {message && (
          <p className="mt-4 text-emerald-400">
            {message}
          </p>
        )}
      </div>

      <div className="bg-[#0f172a] rounded-2xl border border-slate-700 p-6">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-semibold text-white">
            Platform Users
          </h2>

          <input
            className="rounded-lg bg-slate-950 border border-slate-700 px-4 py-2 text-white"
            placeholder="Search user..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {error && (
          <div className="mb-4 rounded-xl bg-red-500/10 border border-red-500/30 p-4 text-red-400">
            {error}
          </div>
        )}

        <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          {filteredUsers.map((user) => {
            const initials = user.username
              .split(" ")
              .map((word) => word[0])
              .join("")
              .slice(0, 2)
              .toUpperCase();

            return (
              <div
                key={user.id}
                className="overflow-hidden rounded-2xl border border-slate-700 bg-slate-950"
              >
                <label
                  className="relative block h-28 cursor-pointer bg-gradient-to-r from-cyan-500/30 via-blue-500/20 to-emerald-500/30"
                  style={{
                    backgroundImage: user.cover_url
                      ? `linear-gradient(rgba(2,6,23,0.25),rgba(2,6,23,0.7)), url(${user.cover_url})`
                      : undefined,
                    backgroundSize: "cover",
                    backgroundPosition: "center",
                  }}
                >
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) =>
                      uploadUserAssets(user.id, null, e.target.files?.[0])
                    }
                  />

                  <span className="absolute right-3 top-3 rounded-full bg-slate-950/70 px-3 py-1 text-xs text-cyan-300 backdrop-blur">
                    Change Cover
                  </span>
                </label>

                <div className="relative px-5 pb-5">
                  <div className="-mt-10 mb-3 flex items-end justify-between">
                    <label className="relative flex h-20 w-20 cursor-pointer items-center justify-center overflow-hidden rounded-2xl border-4 border-slate-950 bg-slate-800 text-2xl font-bold text-cyan-300">
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) =>
                          uploadUserAssets(user.id, e.target.files?.[0], null)
                        }
                      />

                      {user.photo_url ? (
                        <img
                          src={user.photo_url}
                          alt={user.username}
                          className="h-full w-full object-cover"
                        />
                      ) : (
                        initials
                      )}

                      <span className="absolute inset-x-0 bottom-0 bg-slate-950/80 py-1 text-center text-[10px] text-cyan-300">
                        Change
                      </span>
                    </label>

                    <span
                      className={`rounded-full border px-3 py-1 text-xs ${badgeColor(
                        user.role
                      )}`}
                    >
                      {user.role}
                    </span>
                  </div>

                  <h3 className="text-lg font-bold text-white">
                    {user.username}
                  </h3>

                  {uploadingUserId === user.id && (
                    <p className="mt-1 text-sm text-cyan-300">
                      Uploading image...
                    </p>
                  )}

                  <p className="text-sm text-slate-500">
                    User ID: {user.id}
                  </p>

                  {user.email && (
                    <p className="mt-1 text-sm text-slate-400">
                      {user.email}
                    </p>
                  )}

                  <p className="mt-2 text-xs text-slate-500">
                    Created: {new Date(user.created_at).toLocaleString()}
                  </p>

                  <div className="mt-5 grid grid-cols-2 gap-2">
                    <label className="cursor-pointer rounded-lg border border-cyan-500/30 bg-cyan-500/10 px-3 py-2 text-center text-sm text-cyan-300 hover:bg-cyan-500/20">
                      Upload Photo
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) =>
                          uploadUserAssets(
                            user.id,
                            e.target.files?.[0],
                            null
                          )
                        }
                      />
                    </label>

                    <label className="cursor-pointer rounded-lg border border-violet-500/30 bg-violet-500/10 px-3 py-2 text-center text-sm text-violet-300 hover:bg-violet-500/20">
                      Upload Cover
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) =>
                          uploadUserAssets(
                            user.id,
                            null,
                            e.target.files?.[0]
                          )
                        }
                      />
                    </label>
                  </div>

                  <div className="mt-3 flex gap-2">
                    <select
                      value={pendingRoles[user.id] ?? user.role}
                      onChange={(e) => {
                        const nextRole = e.target.value;
                        setPendingRoles((prev) => ({
                          ...prev,
                          [user.id]: nextRole,
                        }));
                        updateRole(user.id, user.username, nextRole);
                      }}
                      className="flex-1 rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-white"
                    >
                      <option>Admin</option>
                      <option>Engineer</option>
                      <option>Viewer</option>
                    </select>

                    <button
                      onClick={() => deleteUser(user.id)}
                      disabled={user.id === 1}
                      className="rounded-lg border border-red-500/30 px-3 py-2 text-sm text-red-400 hover:bg-red-500/10 disabled:opacity-30"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}