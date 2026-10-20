require("dotenv").config();

const { withStoreAsync, newId } = require("../src/store");
const { setUserPassword } = require("../src/passwords");
const { normalizePhone, normalizeString } = require("../src/utils/values");

function adminEnv(env = process.env) {
  return {
    phone: normalizePhone(env.MTAXI_ADMIN_PHONE || "+70000000000"),
    password: normalizeString(env.MTAXI_ADMIN_PASSWORD),
    displayName: normalizeString(env.MTAXI_ADMIN_NAME || "Администратор"),
    city: normalizeString(env.MTAXI_ADMIN_CITY || ""),
  };
}

function validateAdminConfig(config) {
  if (!config.phone || !config.phone.startsWith("+")) {
    return "MTAXI_ADMIN_PHONE must be a normalized phone number";
  }
  if (config.password.length < 6) {
    return "MTAXI_ADMIN_PASSWORD must be at least 6 characters";
  }
  return "";
}

async function seedAdmin({ env = process.env, now = new Date().toISOString() } = {}) {
  const config = adminEnv(env);
  const error = validateAdminConfig(config);
  if (error) {
    return { success: false, code: "ADMIN_SEED_INVALID", error };
  }

  return withStoreAsync(async (store) => {
    store.users ||= [];
    const existing = store.users.find((user) => normalizePhone(user.phone) === config.phone);
    const user = existing || {
      id: newId("u_admin"),
      createdAt: now,
      balance: 0,
      isDriver: false,
    };

    user.phone = config.phone;
    user.displayName = config.displayName;
    user.firstName = config.displayName.split(/\s+/).filter(Boolean)[0] || config.displayName;
    user.lastName = config.displayName.split(/\s+/).filter(Boolean).slice(1).join(" ");
    user.city = config.city || user.city || "";
    user.role = "admin";
    user.roleState = "ADMIN";
    user.activeMode = "admin";
    user.preferredClientMode = "admin";
    user.profileCompleted = true;
    user.registrationDraft = false;
    user.blocked = false;
    user.updatedAt = now;
    setUserPassword(user, config.password);

    if (!existing) {
      store.users.push(user);
    }

    store.auditLogs ||= [];
    store.auditLogs.push({
      id: newId("audit"),
      action: existing ? "seedAdminUpdate" : "seedAdminCreate",
      target: `users/${user.id}`,
      adminId: user.id,
      adminPhone: user.phone,
      before: null,
      after: {
        id: user.id,
        phone: user.phone,
        role: user.role,
        roleState: user.roleState,
        displayName: user.displayName,
      },
      extra: { source: "seed_admin" },
      createdAt: now,
    });

    return {
      success: true,
      code: existing ? "ADMIN_SEEDED_UPDATED" : "ADMIN_SEEDED_CREATED",
      userId: user.id,
      phone: user.phone,
    };
  });
}

async function main() {
  const result = await seedAdmin();
  if (!result.success) {
    console.error(result.error);
    process.exit(1);
  }
  console.log(`${result.code}: ${result.phone} (${result.userId})`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error?.message || error);
    process.exit(1);
  });
}

module.exports = {
  adminEnv,
  seedAdmin,
};
