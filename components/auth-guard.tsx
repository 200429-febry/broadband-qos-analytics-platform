"use client";

import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";

const publicPaths = ["/login", "/auth/google-success"];

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();

  const [allowed, setAllowed] = useState(false);

  useEffect(() => {
    if (publicPaths.some((path) => pathname.startsWith(path))) {
      setAllowed(true);
      return;
    }

    const token =
      localStorage.getItem("access_token") ||
      localStorage.getItem("token");

    const userRaw = localStorage.getItem("user");

    if (!token || !userRaw) {
      router.push("/login");
      return;
    }

    let user: any = null;

    try {
      user = JSON.parse(userRaw);
    } catch {
      router.push("/login");
      return;
    }

    const adminOnlyPaths = [
      "/users",
      "/settings",
      "/database",
      "/audit",
    ];

    if (
      adminOnlyPaths.some((path) => pathname.startsWith(path)) &&
      user.role !== "Admin"
    ) {
      router.push("/");
      return;
    }

    setAllowed(true);
  }, [pathname, router]);

  if (!allowed) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-950 text-white">
        Loading secure workspace...
      </div>
    );
  }

  return <>{children}</>;
}
