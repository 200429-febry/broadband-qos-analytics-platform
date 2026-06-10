"use client";

import dynamic from "next/dynamic";

const CoverageMapClient = dynamic(
  () => import("@/components/coverage-map-client").then((mod) => mod.CoverageMapClient),
  { ssr: false }
);

export default function CoveragePage() {
  return <CoverageMapClient />;
}
