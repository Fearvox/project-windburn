export const authContractVersion = "auth-contract-v0";

const roleRank = {
  viewer: 0,
  operator: 1,
  admin: 2,
};

export const authRoles = Object.freeze({
  viewer: Object.freeze({
    label: "Viewer",
    purpose: "Public, redacted status reading.",
    grants: Object.freeze(["read_redacted_status", "read_openapi"]),
  }),
  operator: Object.freeze({
    label: "Operator",
    purpose: "Human-approved task staging after authentication.",
    grants: Object.freeze(["read_redacted_status", "stage_task"]),
  }),
  admin: Object.freeze({
    label: "Admin",
    purpose: "Provider, webhook, and auth configuration.",
    grants: Object.freeze(["read_redacted_status", "stage_task", "configure_providers", "configure_auth"]),
  }),
});

export const authRouteContracts = Object.freeze([
  Object.freeze({
    id: "public-health",
    match: "/healthz",
    methods: Object.freeze(["GET", "HEAD"]),
    minRole: "viewer",
    redaction: "public",
    enabled: true,
  }),
  Object.freeze({
    id: "public-status",
    match: "/api/status",
    methods: Object.freeze(["GET", "HEAD"]),
    minRole: "viewer",
    redaction: "public",
    enabled: true,
  }),
  Object.freeze({
    id: "public-superruntime",
    match: "/api/superruntime",
    methods: Object.freeze(["GET", "HEAD"]),
    minRole: "viewer",
    redaction: "public",
    enabled: true,
  }),
  Object.freeze({
    id: "public-openapi",
    match: "/openapi.json",
    methods: Object.freeze(["GET", "HEAD"]),
    minRole: "viewer",
    redaction: "public",
    enabled: true,
  }),
  Object.freeze({
    id: "operator-task-stage",
    match: "/api/tasks/stage",
    methods: Object.freeze(["POST"]),
    minRole: "operator",
    redaction: "private",
    enabled: false,
  }),
  Object.freeze({
    id: "admin-config",
    match: "/api/admin/",
    methods: Object.freeze(["GET", "HEAD", "POST"]),
    minRole: "admin",
    redaction: "private",
    enabled: false,
    prefix: true,
  }),
]);

export function publicAuthContext() {
  return {
    authenticated: false,
    role: "viewer",
    source: "public",
  };
}

function routeMatches(contract, pathname) {
  if (contract.prefix) return pathname.startsWith(contract.match);
  return pathname === contract.match;
}

export function guardRoute({ pathname, method = "GET", role = "viewer" }) {
  const normalizedMethod = method.toUpperCase();
  const normalizedRole = roleRank[role] === undefined ? "viewer" : role;
  const route = authRouteContracts.find((contract) => routeMatches(contract, pathname));

  if (!route) {
    return { allowed: true, route: null, reason: "unmatched_route" };
  }

  if (!route.enabled) {
    return {
      allowed: false,
      route,
      status: 404,
      reason: "route_not_enabled",
    };
  }

  if (!route.methods.includes(normalizedMethod)) {
    return {
      allowed: false,
      route,
      status: 405,
      reason: "method_not_allowed",
    };
  }

  if (roleRank[normalizedRole] < roleRank[route.minRole]) {
    return {
      allowed: false,
      route,
      status: 403,
      reason: "insufficient_role",
    };
  }

  return { allowed: true, route, reason: "allowed" };
}

export function authContractSummary(activeRole = "viewer") {
  return {
    version: authContractVersion,
    active_role: roleRank[activeRole] === undefined ? "viewer" : activeRole,
    roles: Object.entries(authRoles).map(([id, role]) => ({
      id,
      label: role.label,
      purpose: role.purpose,
      grants: [...role.grants],
    })),
    route_guards: authRouteContracts.map((route) => ({
      id: route.id,
      match: route.match,
      methods: [...route.methods],
      min_role: route.minRole,
      redaction: route.redaction,
      enabled: route.enabled,
    })),
    public_viewer_policy: "redacted status only",
    operator_policy: "stage tasks only after authentication and explicit confirmation",
    admin_policy: "provider, webhook, and auth configuration only after admin authentication",
    mutation_routes_enabled: false,
  };
}
