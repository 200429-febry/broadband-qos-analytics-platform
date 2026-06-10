"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { CheckCircle2, Loader2, Phone, ShieldCheck, UserCircle2 } from "lucide-react";

function getEmailFromUrl(params: URLSearchParams) {
  return (
    params.get("email") ||
    params.get("account") ||
    params.get("user") ||
    params.get("login_hint") ||
    localStorage.getItem("pending_google_email") ||
    localStorage.getItem("google_email") ||
    "febriyadi845@gmail.com"
  );
}

export default function GoogleSuccessPage() {
  const router = useRouter();
  const params = useSearchParams();

  const [email, setEmail] = useState("");
  const [isTeam, setIsTeam] = useState(false);
  const [phone, setPhone] = useState("");
  const [accessCode, setAccessCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");
  const [rolePreview, setRolePreview] = useState("Viewer");

  useEffect(() => {
    const e = getEmailFromUrl(params);
    setEmail(e);
  }, [params]);

  useEffect(() => {
    const digits = phone.replace(/[^0-9]/g, "");
    const emailAllowed =
      email.toLowerCase() === "febriyadi845@gmail.com" ||
      email.toLowerCase() === "muhammad.febryadi.te23@stu.pnj.ac.id";
    const phoneAllowed = digits.endsWith("1027") || digits.endsWith("845");
    setRolePreview(isTeam && (emailAllowed || phoneAllowed) ? "Admin" : "Viewer");
  }, [email, phone, isTeam]);

  const canSubmit = useMemo(() => {
    if (!email) return false;
    if (isTeam && phone.replace(/[^0-9]/g, "").length < 4) return false;
    return true;
  }, [email, phone, isTeam]);

  async function finalizeLogin() {
    if (!canSubmit) {
      setMessage("Masukkan nomor telepon tim terlebih dahulu.");
      return;
    }

    setLoading(true);
    setMessage("");

    try {
      const res = await fetch("/api/auth/google-finalize", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        cache: "no-store",
        body: JSON.stringify({
          email,
          isTeam,
          phone,
          accessCode,
        }),
      });

      const data = await res.json();

      if (!res.ok) {
        setMessage(data?.detail || data?.error || "Failed to finalize Google Sign-In.");
        setLoading(false);
        return;
      }

      localStorage.setItem("token", data.access_token || "");
      localStorage.setItem("access_token", data.access_token || "");
      localStorage.setItem("username", data.username || email.split("@")[0]);
      localStorage.setItem("email", data.email || email);
      localStorage.setItem("role", data.role || "Viewer");
      localStorage.setItem(
        "user",
        JSON.stringify({
          id: data.id,
          username: data.username || email.split("@")[0],
          email: data.email || email,
          role: data.role || "Viewer",
        })
      );

      setMessage(`Login completed as ${data.role || "Viewer"}. Redirecting...`);
      setTimeout(() => router.push("/"), 700);
    } catch {
      setMessage("Failed to fetch. Check frontend API route or backend service.");
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950 p-6 text-white">
      <section className="w-full max-w-xl rounded-3xl border border-cyan-500/30 bg-slate-900/80 p-8 shadow-2xl">
        <div className="text-center">
          <div className="mx-auto mb-5 flex h-16 w-16 items-center justify-center rounded-2xl border border-cyan-500/30 bg-cyan-500/10">
            <ShieldCheck className="h-8 w-8 text-cyan-300" />
          </div>

          <h1 className="text-3xl font-black text-cyan-300">Complete Google Sign-In</h1>
          <p className="mt-3 text-slate-400">
            Google account will be finalized into the AKSARA Union platform session.
          </p>
        </div>

        <div className="mt-8 space-y-5">
          <div className="rounded-2xl border border-slate-700 bg-slate-950 p-5">
            <div className="mb-2 flex items-center gap-2 text-slate-400">
              <UserCircle2 className="h-4 w-4" />
              <p className="text-sm">Google Account</p>
            </div>
            <input
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-xl border border-slate-800 bg-slate-900 px-4 py-3 font-bold text-white"
              placeholder="name@example.com"
            />
          </div>

          <label className="block cursor-pointer rounded-2xl border border-slate-700 bg-slate-950 p-5">
            <div className="flex items-start gap-4">
              <input
                type="checkbox"
                checked={isTeam}
                onChange={(e) => setIsTeam(e.target.checked)}
                className="mt-1 h-5 w-5"
              />
              <div>
                <p className="font-black text-white">Are you AKSARA Team?</p>
                <p className="mt-1 text-sm text-slate-400">
                  Team access requires registered email or phone verification.
                </p>
              </div>
            </div>
          </label>

          {isTeam ? (
            <div className="space-y-4 rounded-2xl border border-cyan-500/30 bg-cyan-500/10 p-5">
              <div>
                <div className="mb-2 flex items-center gap-2 text-cyan-300">
                  <Phone className="h-4 w-4" />
                  <p className="text-sm font-bold">Team Phone Number</p>
                </div>
                <input
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="w-full rounded-xl border border-cyan-500/30 bg-slate-950 px-4 py-3 text-white"
                  placeholder="Contoh: 08xxxxxxxxxx"
                />
                <p className="mt-2 text-xs text-slate-400">
                  Untuk demo saat ini, email Febryadi atau nomor berakhiran 1027 / 845 akan mendapat Admin.
                </p>
              </div>

              <div>
                <p className="mb-2 text-sm font-bold text-cyan-300">Optional Access Note</p>
                <input
                  value={accessCode}
                  onChange={(e) => setAccessCode(e.target.value)}
                  className="w-full rounded-xl border border-cyan-500/30 bg-slate-950 px-4 py-3 text-white"
                  placeholder="Contoh: AKSARA internal team"
                />
              </div>
            </div>
          ) : null}

          <div className="rounded-2xl border border-slate-700 bg-slate-950 p-5">
            <p className="text-sm text-slate-400">Role Preview</p>
            <p className={rolePreview === "Admin" ? "mt-1 text-2xl font-black text-emerald-300" : "mt-1 text-2xl font-black text-cyan-300"}>
              {rolePreview}
            </p>
          </div>

          <button
            onClick={finalizeLogin}
            disabled={loading}
            className="w-full rounded-2xl bg-cyan-400 px-5 py-4 font-black text-slate-950 hover:bg-cyan-300 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? (
              <>
                <Loader2 className="mr-2 inline h-5 w-5 animate-spin" />
                Finalizing...
              </>
            ) : (
              <>
                <CheckCircle2 className="mr-2 inline h-5 w-5" />
                Continue to Dashboard
              </>
            )}
          </button>

          {message ? (
            <div className="rounded-2xl border border-slate-700 bg-slate-950 p-4 text-center text-sm text-slate-300">
              {message}
            </div>
          ) : null}
        </div>
      </section>
    </main>
  );
}
