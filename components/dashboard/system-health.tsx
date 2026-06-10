"use client";

import React, { useEffect, useState } from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { CheckCircle2, AlertCircle, XCircle } from "lucide-react";

interface Service {
  name: string;
  status: "operational" | "degraded" | "down";
  latency: string;
}

export function SystemHealth() {
  const [services, setServices] = useState<Service[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchHealth = async () => {
      try {
        const response = await fetch(`https://qos-api-gh3tn2a6oa-et.a.run.app/api/health`);

        if (!response.ok) {
          throw new Error("Health API failed");
        }

        const data = await response.json();

        setServices([
          {
            name: "API Service",
            status: data.api_service || "down",
            latency: "24ms",
          },
          {
            name: "Database",
            status: data.database || "down",
            latency: "12ms",
          },
          {
            name: "ML Service",
            status: data.ml_service || "down",
            latency: "85ms",
          },
        ]);

        setError(null);
      } catch (error) {
        console.error("Failed to fetch system health:", error);
        setError("Unable to fetch system health");

        setServices([
          {
            name: "API Service",
            status: "down",
            latency: "-",
          },
          {
            name: "Database",
            status: "down",
            latency: "-",
          },
          {
            name: "ML Service",
            status: "down",
            latency: "-",
          },
        ]);
      }
    };

    fetchHealth();

    const interval = setInterval(fetchHealth, 10000);

    return () => clearInterval(interval);
  }, []);

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-slate-200">System Health</CardTitle>
      </CardHeader>

      <CardContent>
        {error && (
          <p className="mb-3 text-xs text-red-400">
            {error}
          </p>
        )}

        <div className="space-y-4">
          {services.map((service) => (
            <div
              key={service.name}
              className="flex items-center justify-between p-3 rounded-lg bg-white/5 border border-white/5"
            >
              <div className="flex items-center gap-3">
                {service.status === "operational" ? (
                  <CheckCircle2 className="h-4 w-4 text-emerald-500" />
                ) : service.status === "degraded" ? (
                  <AlertCircle className="h-4 w-4 text-amber-500" />
                ) : (
                  <XCircle className="h-4 w-4 text-red-500" />
                )}

                <span className="text-sm font-medium text-slate-300">
                  {service.name}
                </span>
              </div>

              <div className="flex items-center gap-4 text-sm">
                <span className="text-slate-500 font-mono">
                  {service.latency}
                </span>

                <span
                  className={`px-2 py-1 rounded text-xs tracking-wide uppercase font-semibold ${
                    service.status === "operational"
                      ? "bg-emerald-500/10 text-emerald-400"
                      : service.status === "degraded"
                      ? "bg-amber-500/10 text-amber-400"
                      : "bg-red-500/10 text-red-400"
                  }`}
                >
                  {service.status}
                </span>
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}