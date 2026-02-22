// [FREEZE] — Gate 0 locked
import { HTMLAttributes, forwardRef } from "react";

interface ScreenProps extends HTMLAttributes<HTMLDivElement> {
  padded?: boolean;
}

export const Screen = forwardRef<HTMLDivElement, ScreenProps>(
  ({ padded = true, className = "", children, ...props }, ref) => (
    <div
      ref={ref}
      className={`min-h-screen ${padded ? "px-4 py-6" : ""} ${className}`}
      {...props}
    >
      {children}
    </div>
  )
);
Screen.displayName = "Screen";
