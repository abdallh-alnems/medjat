import { LoadingState } from "@/components/ui/states";

/** Shown in the content area while a route segment loads during navigation. */
export default function Loading() {
  return (
    <div className="flex min-h-[40vh] items-center justify-center">
      <LoadingState />
    </div>
  );
}
