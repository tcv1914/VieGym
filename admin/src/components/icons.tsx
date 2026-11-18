import type { SVGProps } from 'react';

type IconProps = SVGProps<SVGSVGElement> & { size?: number };

function baseProps(size = 18, props?: IconProps): SVGProps<SVGSVGElement> {
  const { size: _size, ...rest } = props ?? {};
  void _size;
  return {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 2,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    'aria-hidden': true,
    ...rest,
  };
}

export function IconDashboard({ size = 18, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <rect x="3" y="3" width="7" height="9" rx="1.5" />
      <rect x="14" y="3" width="7" height="5" rx="1.5" />
      <rect x="14" y="12" width="7" height="9" rx="1.5" />
      <rect x="3" y="16" width="7" height="5" rx="1.5" />
    </svg>
  );
}

export function IconDumbbell({ size = 18, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M6.5 6.5 17.5 17.5" />
      <path d="m21 21-1-1" />
      <path d="m3 3 1 1" />
      <path d="m18 22 4-4" />
      <path d="m2 6 4-4" />
      <path d="m3 10 7-7" />
      <path d="m14 21 7-7" />
    </svg>
  );
}

export function IconBowl({ size = 18, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M4 11h16a1 1 0 0 1 1 1v.5a8 8 0 0 1-5.5 7.6V21h-7v-.9A8 8 0 0 1 3 12.5V12a1 1 0 0 1 1-1Z" />
      <path d="M8 7c0-1.5 1-2.5 1-4" />
      <path d="M12 7c0-1.5 1-2.5 1-4" />
      <path d="M16 7c0-1.5 1-2.5 1-4" />
    </svg>
  );
}

export function IconUsers({ size = 18, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  );
}

export function IconSearch({ size = 16, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </svg>
  );
}

export function IconPlus({ size = 16, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M12 5v14" />
      <path d="M5 12h14" />
    </svg>
  );
}

export function IconEdit({ size = 15, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M12 20h9" />
      <path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z" />
    </svg>
  );
}

export function IconLock({ size = 15, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <rect width="18" height="11" x="3" y="11" rx="2" ry="2" />
      <path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </svg>
  );
}

export function IconUnlock({ size = 15, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <rect width="18" height="11" x="3" y="11" rx="2" ry="2" />
      <path d="M7 11V7a5 5 0 0 1 9.9-1" />
    </svg>
  );
}

export function IconLogOut({ size = 16, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <polyline points="16 17 21 12 16 7" />
      <line x1="21" x2="9" y1="12" y2="12" />
    </svg>
  );
}

export function IconRefresh({ size = 16, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
      <path d="M3 3v5h5" />
      <path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16" />
      <path d="M16 16h5v5" />
    </svg>
  );
}

export function IconShield({ size = 16, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z" />
      <path d="m9 12 2 2 4-4" />
    </svg>
  );
}

export function IconActivity({ size = 18, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2" />
    </svg>
  );
}

export function IconEye({ size = 16, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

export function IconEyeOff({ size = 16, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49" />
      <path d="M14.084 14.158a3 3 0 0 1-4.242-4.242" />
      <path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143" />
      <path d="m2 2 20 20" />
    </svg>
  );
}

export function IconCheckCircle({ size = 16, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
      <path d="m9 11 3 3L22 4" />
    </svg>
  );
}

export function IconAlertCircle({ size = 16, ...props }: IconProps) {
  return (
    <svg {...baseProps(size, props)}>
      <circle cx="12" cy="12" r="10" />
      <line x1="12" x2="12" y1="8" y2="12" />
      <line x1="12" x2="12.01" y1="16" y2="16" />
    </svg>
  );
}
