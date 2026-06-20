"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { useT } from "@/lib/i18n/use-t";
import type {
  BranchPerformance,
} from "@/lib/types";

const PALETTE = ["#2563EB", "#60A5FA", "#B8860B", "#27AE60", "#D4A017"];

export function BranchComparison({ data }: { data: BranchPerformance[] }) {
  const { t } = useT();
  const ranked = [...data].sort((a, b) => b.rate - a.rate);
  return (
    <div className="card-flat">
      <h3 className="mb-3 text-title-lg font-semibold">
        {t("branch_comparison")}
      </h3>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={ranked} margin={{ top: 4, right: 8, left: 8, bottom: 4 }}>
            <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
            <XAxis
              dataKey="branch_name"
              tick={{ fontSize: 12 }}
              className="text-muted-foreground"
            />
            <YAxis
              domain={[0, 1]}
              tickFormatter={(v) => `${Math.round(Number(v) * 100)}%`}
              tick={{ fontSize: 12 }}
            />
            <Tooltip
              formatter={(v) =>
                [`${Math.round(Number(v) * 100)}%`, t("attendance_rate")]
              }
            />
            <Bar dataKey="rate" radius={[6, 6, 0, 0]}>
              {ranked.map((_, i) => (
                <Cell key={i} fill={PALETTE[i % PALETTE.length]} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

export function CategoryDistribution({
  data,
}: {
  data: { category: string; count: number }[];
}) {
  const { t } = useT();
  return (
    <div className="card-flat">
      <h3 className="mb-3 text-title-lg font-semibold">
        {t("category_distribution")}
      </h3>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              dataKey="count"
              nameKey="category"
              outerRadius={80}
              label={(e: { name?: string }) => e.name}
            >
              {data.map((_, i) => (
                <Cell key={i} fill={PALETTE[i % PALETTE.length]} />
              ))}
            </Pie>
            <Tooltip />
          </PieChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
