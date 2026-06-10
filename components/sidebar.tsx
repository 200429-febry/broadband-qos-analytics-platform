"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import {
  Activity,
  BarChart3,
  Radio,
  Network,
  Server,
  FileText,
  History,
  AlertTriangle,
  Settings,
  Users,
  BrainCircuit,
  Map,
  Database,
  ClipboardList,
  Rocket,
  LineChart,
} from "lucide-react";
import { cn } from "@/lib/utils";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

const navigation = [
  { name: "Dashboard", href: "/", icon: BarChart3, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Realtime Monitor", href: "/monitoring", icon: Activity, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Streaming QoE", href: "/streaming-qoe", icon: Activity, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "QoS Analytics", href: "/analytics", icon: Radio, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Coverage Map", href: "/coverage", icon: Map, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Prediction ML", href: "/predictions", icon: BrainCircuit, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Stream Health", href: "/stream", icon: Server, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Incidents", href: "/incidents", icon: History, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Reports", href: "/reports", icon: FileText, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Deployment", href: "/deployment", icon: Rocket, roles: ["Admin", "Engineer"] },
  { name: "Observability", href: "/observability", icon: LineChart, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Alert Center", href: "/alerts", icon: AlertTriangle, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Topology", href: "/topology", icon: Network, roles: ["Admin", "Engineer", "Viewer"] },
  { name: "Database Monitor", href: "/database", icon: Database, roles: ["Admin"] },
  { name: "Audit Log", href: "/audit", icon: ClipboardList, roles: ["Admin"] },
  { name: "User Management", href: "/users", icon: Users, roles: ["Admin"] },
  { name: "Settings", href: "/settings", icon: Settings, roles: ["Admin"] },
];

type SidebarUser = {
  id?: number;
  username?: string;
  role?: string;
  email?: string;
  photo_url?: string;
  cover_url?: string;
};

function readStoredUser(): SidebarUser {
  try {
    const raw = localStorage.getItem("user");
    if (!raw) return { username: "Guest", role: "Viewer" };
    return JSON.parse(raw);
  } catch {
    return { username: "Guest", role: "Viewer" };
  }
}

export function Sidebar() {
  const pathname = usePathname();

  const [user, setUser] = useState<SidebarUser>({
    username: "Guest",
    role: "Viewer",
  });

  const [isCompact, setIsCompact] = useState(false);

  useEffect(() => {
    const loadUser = async () => {
      const storedUser = readStoredUser();
      setUser(storedUser);

      const token =
        localStorage.getItem("access_token") ||
        localStorage.getItem("token");

      if (!token || !storedUser.username) return;

      try {
        const response = await fetch(`${API_URL}/api/users`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
          cache: "no-store",
        });

        const data = await response.json();

        if (!Array.isArray(data)) return;

        const freshUser = data.find(
          (item) =>
            String(item.id) === String(storedUser.id) ||
            item.username === storedUser.username ||
            item.email === storedUser.email
        );

        if (freshUser) {
          const mergedUser = {
            ...storedUser,
            ...freshUser,
          };

          setUser(mergedUser);
          localStorage.setItem("user", JSON.stringify(mergedUser));
        }
      } catch {
        // keep local user if API refresh fails
      }
    };

    const applySettings = () => {
      setIsCompact(localStorage.getItem("sidebarMode") === "Compact");
    };

    loadUser();
    applySettings();

    window.addEventListener("focus", loadUser);
    window.addEventListener("storage", loadUser);
    window.addEventListener("app-user-updated", loadUser);
    window.addEventListener("app-settings-changed", applySettings);

    return () => {
      window.removeEventListener("focus", loadUser);
      window.removeEventListener("storage", loadUser);
      window.removeEventListener("app-user-updated", loadUser);
      window.removeEventListener("app-settings-changed", applySettings);
    };
  }, []);

  const allowedNavigation = navigation.filter((item) =>
    item.roles.includes(user.role || "Viewer")
  );

  const initials =
    user.username
      ?.split("_")
      .map((part) => part[0])
      .join("")
      .slice(0, 2)
      .toUpperCase() || "US";

  const photoUrl = user.photo_url
    ? `${user.photo_url}${user.photo_url.includes("?") ? "&" : "?"}sidebar=${Date.now()}`
    : "";

  return (
    <div
      className={cn(
        "flex h-full flex-col border-r border-slate-800 bg-slate-950 transition-all duration-300",
        isCompact ? "w-20" : "w-64"
      )}
    >
      <div className="border-b border-slate-800 px-4 py-4">
        <div
          className={cn(
            "flex items-center",
            isCompact ? "justify-center" : "gap-3"
          )}
        >
          <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-white p-1 shadow-lg">
            <Image
              src="/aksara-union.svg"
              alt="Aksara Union"
              width={42}
              height={42}
              className="object-contain"
              priority
            />
          </div>

          {!isCompact && (
            <div>
              <h1 className="text-sm font-bold tracking-wide text-slate-100">
                AKSARA UNION
              </h1>
              <p className="text-[11px] text-slate-400">
                QoS Analytics Platform
              </p>
            </div>
          )}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto py-5">
        {!isCompact && (
          <div className="mb-4 px-4">
            <p className="text-[11px] font-semibold uppercase tracking-widest text-slate-500">
              Main Menu
            </p>
          </div>
        )}

        <nav className="space-y-1 px-3">
          {allowedNavigation.map((item) => {
            const isActive = pathname === item.href;

            return (
              <Link
                key={item.name}
                href={item.href}
                title={isCompact ? item.name : undefined}
                className={cn(
                  isActive
                    ? "border border-emerald-500/20 bg-emerald-500/15 text-emerald-400"
                    : "text-slate-400 hover:bg-slate-800 hover:text-slate-200",
                  "group flex items-center rounded-xl px-3 py-2.5 text-sm font-medium transition-all duration-200",
                  isCompact ? "justify-center" : ""
                )}
              >
                <item.icon
                  className={cn(
                    isActive
                      ? "text-emerald-400"
                      : "text-slate-500 group-hover:text-slate-300",
                    "h-5 w-5 flex-shrink-0 transition-colors",
                    isCompact ? "mr-0" : "mr-3"
                  )}
                />

                {!isCompact && <span className="truncate">{item.name}</span>}
              </Link>
            );
          })}
        </nav>
      </div>

      <div className="border-t border-slate-800 p-4">
        <div
          className={cn(
            "flex items-center rounded-xl bg-slate-900 px-3 py-3",
            isCompact ? "justify-center" : "gap-3"
          )}
        >
          <div className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full border border-emerald-500/30 bg-emerald-500/10">
            {photoUrl ? (
              <img
                src={photoUrl}
                alt={user.username || "User"}
                className="h-full w-full object-cover"
              />
            ) : (
              <span className="text-xs font-bold text-emerald-400">
                {initials}
              </span>
            )}
          </div>

          {!isCompact && (
            <div className="min-w-0">
              <p className="truncate text-sm font-medium text-slate-200">
                {user.username || "Guest"}
              </p>

              <p className="text-xs text-slate-500">
                {user.role || "Viewer"}
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
