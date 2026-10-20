const { withStoreAsync, newId } = require("./store");
const { normalizeString } = require("./utils/values");
const { requireAdmin, addAudit } = require("./admin");

const ADMIN_USER_ID = "u_admin_70000000000";

function requireAuth(auth) {
  if (!auth?.user) {
    return {
      success: false,
      code: "UNAUTHENTICATED",
      error: "Пользователь не авторизован",
    };
  }
  return null;
}

function docId(value) {
  const text = normalizeString(value);
  return text.split("/").filter(Boolean).pop() || text;
}

function chatPath(chat) {
  return `chats/${chat.id}`;
}

function messagePath(message) {
  return `chat_messages/${message.id}`;
}

function supportKeyFor(userId, adminId = ADMIN_USER_ID) {
  return `users/${userId}|users/${adminId}`;
}

function ensureSupportChatInStore(store, user) {
  store.chats ||= [];
  store.chatMessages ||= [];
  const admin = store.users.find((item) => item.role === "admin") ||
    store.users.find((item) => item.id === ADMIN_USER_ID);
  const adminId = admin?.id || ADMIN_USER_ID;
  const supportChatKey = supportKeyFor(user.id, adminId);
  let chat = store.chats.find((item) => item.supportChatKey === supportChatKey);
  if (!chat) {
    chat = {
      id: newId("chat"),
      supportChatKey,
      userId: user.id,
      adminId,
      users: [`users/${user.id}`, `users/${adminId}`],
      lastMessage: "",
      lastMessageTime: null,
      unreadForUser: 0,
      unreadForAdmin: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    store.chats.push(chat);
  }
  user.supportChatKey = supportChatKey;
  user.supportChatPath = chatPath(chat);
  return { chat, adminId, supportChatKey };
}

function publicChat(chat) {
  if (!chat) return null;
  return {
    ...chat,
    chatPath: chatPath(chat),
  };
}

function publicChatWithUser(store, chat) {
  const result = publicChat(chat);
  if (!result) return null;
  const user = store.users.find((item) => item.id === chat.userId);
  if (user) {
    result.user = {
      id: user.id,
      phone: user.phone,
      displayName: user.displayName,
      city: user.city,
      role: user.role,
    };
    result.userPath = `users/${user.id}`;
  }
  return result;
}

function publicMessage(message) {
  if (!message) return null;
  return {
    ...message,
    messagePath: messagePath(message),
    chatPath: `chats/${message.chatId}`,
  };
}

function findChatByIdOrPath(store, value) {
  const id = docId(value);
  return store.chats.find((chat) => chat.id === id || chat.supportChatKey === value);
}

function ensureSupportChatInContext(store, data, auth) {
  const requester = store.users.find((item) => item.id === auth.user.id);
  const targetUserId = docId(data.targetUserDocPath || data.userDocPath);
  const isAdminRequester = requester?.role === "admin";
  const user = isAdminRequester && targetUserId
    ? store.users.find((item) => item.id === targetUserId)
    : requester;
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  const { chat, adminId, supportChatKey } = ensureSupportChatInStore(store, user);
  return {
    success: true,
    code: "SUPPORT_CHAT_READY",
    chatPath: chatPath(chat),
    adminPath: `users/${adminId}`,
    userPath: `users/${user.id}`,
    supportChatKey,
    supportChatPaths: [chatPath(chat)],
    chat: publicChat(chat),
  };
}

async function ensureSupportChatAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => ensureSupportChatInContext(store, data, auth));
}

async function getMySupportChatAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => getMySupportChatInStore(store, data, auth));
}

function getMySupportChatInStore(store, data, auth) {
  const user = store.users.find((item) => item.id === auth.user.id);
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  const shouldCreate = data.create === true;
  let chat = store.chats?.find((item) => item.userId === user.id) || null;
  if (!chat && shouldCreate) {
    chat = ensureSupportChatInStore(store, user).chat;
  }
  return {
    success: true,
    code: "MY_SUPPORT_CHAT",
    chat: publicChat(chat),
    chatPath: chat ? chatPath(chat) : null,
    supportChatKey: chat?.supportChatKey || user.supportChatKey || null,
    unreadForUser: chat?.unreadForUser || 0,
  };
}

async function sendSupportChatMessageAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  const text = normalizeString(data.text);
  const imageUrl = normalizeString(data.imageUrl);
  if (!text && !imageUrl) {
    return { success: false, code: "MESSAGE_EMPTY", error: "Введите сообщение" };
  }

  return withStoreAsync(async (store) => sendSupportChatMessageInStore(store, data, auth, { text, imageUrl }));
}

function sendSupportChatMessageInStore(store, data, auth, { text, imageUrl }) {
  store.chats ||= [];
  store.chatMessages ||= [];
  const user = store.users.find((item) => item.id === auth.user.id);
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  let chat = findChatByIdOrPath(store, data.chatDocPath);
  if (!chat) {
    chat = ensureSupportChatInStore(store, user).chat;
  }
  if (!chat) {
    return { success: false, code: "CHAT_NOT_FOUND", error: "Чат не найден" };
  }
  const isAdminSender = user.role === "admin";
  if (!isAdminSender && chat.userId !== user.id) {
    return { success: false, code: "CHAT_FORBIDDEN", error: "Нет доступа к чату" };
  }
  const message = {
    id: newId("message"),
    chatId: chat.id,
    userId: user.id,
    userPath: `users/${user.id}`,
    text,
    imageUrl,
    createdAt: new Date().toISOString(),
    readByUser: !isAdminSender,
    readByAdmin: isAdminSender,
  };
  store.chatMessages.push(message);
  chat.lastMessage = text || "Фото";
  chat.lastMessageTime = message.createdAt;
  chat.updatedAt = message.createdAt;
  if (isAdminSender) {
    chat.unreadForUser = (chat.unreadForUser || 0) + 1;
  } else {
    chat.unreadForAdmin = (chat.unreadForAdmin || 0) + 1;
  }
  return {
    success: true,
    code: "MESSAGE_SENT",
    chatPath: chatPath(chat),
    messagePath: messagePath(message),
    supportChatKey: chat.supportChatKey,
    supportChatPaths: [chatPath(chat)],
    message: publicMessage(message),
    chat: publicChat(chat),
  };
}

async function markSupportChatReadAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => markSupportChatReadInStore(store, data, auth));
}

function markSupportChatReadInStore(store, data, auth) {
  const chat = findChatByIdOrPath(store, data.chatDocPath || data.supportChatKey);
  if (!chat) {
    return { success: false, code: "CHAT_NOT_FOUND", error: "Чат не найден" };
  }
  const user = store.users.find((item) => item.id === auth.user.id);
  const isAdminReader = user?.role === "admin";
  if (!isAdminReader && chat.userId !== auth.user.id) {
    return { success: false, code: "CHAT_FORBIDDEN", error: "Нет доступа к чату" };
  }
  for (const message of store.chatMessages || []) {
    if (message.chatId !== chat.id) continue;
    if (isAdminReader) {
      message.readByAdmin = true;
    } else {
      message.readByUser = true;
    }
  }
  if (isAdminReader) {
    chat.unreadForAdmin = 0;
    chat.adminReadAt = new Date().toISOString();
  } else {
    chat.unreadForUser = 0;
    chat.userReadAt = new Date().toISOString();
  }
  chat.updatedAt = new Date().toISOString();
  return {
    success: true,
    code: "CHAT_MARKED_READ",
    chatPath: chatPath(chat),
    supportChatKey: chat.supportChatKey,
    supportChatPaths: [chatPath(chat)],
    chat: publicChat(chat),
  };
}

async function listSupportChatsAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => listSupportChatsInStore(store, data));
}

function listSupportChatsInStore(store, data) {
  const chats = [...(store.chats || [])]
    .sort((a, b) => normalizeString(b.updatedAt).localeCompare(normalizeString(a.updatedAt)))
    .slice(0, Math.max(1, Number(data.limit) || 100))
    .map((chat) => publicChatWithUser(store, chat));
  return {
    success: true,
    code: "SUPPORT_CHATS",
    chats,
  };
}

async function getSupportChatMessagesAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => getSupportChatMessagesInStore(store, data, auth));
}

function getSupportChatMessagesInStore(store, data, auth) {
  const chat = findChatByIdOrPath(store, data.chatDocPath || data.supportChatKey);
  if (!chat) return { success: false, code: "CHAT_NOT_FOUND", error: "Чат не найден" };
  const user = store.users.find((item) => item.id === auth.user.id);
  const isAdminReader = user?.role === "admin";
  if (!isAdminReader && chat.userId !== auth.user.id) {
    return { success: false, code: "CHAT_FORBIDDEN", error: "Нет доступа к чату" };
  }
  const messages = (store.chatMessages || [])
    .filter((message) => message.chatId === chat.id)
    .sort((a, b) => normalizeString(a.createdAt).localeCompare(normalizeString(b.createdAt)))
    .map(publicMessage);
  return {
    success: true,
    code: "SUPPORT_MESSAGES",
    chat: publicChat(chat),
    messages,
  };
}

async function adminSendSupportChatMessageAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return sendSupportChatMessageAsync(data, auth);
}

function removeSupportChatsFromStore(store, chatsToRemove) {
  const ids = new Set(chatsToRemove.map((chat) => chat.id));
  const beforeChats = [...(store.chats || [])];
  const beforeMessages = [...(store.chatMessages || [])];
  store.chats = beforeChats.filter((chat) => !ids.has(chat.id));
  store.chatMessages = beforeMessages.filter((message) => !ids.has(message.chatId));
  for (const user of store.users || []) {
    if (chatsToRemove.some((chat) => chat.userId === user.id)) {
      delete user.supportChatKey;
      delete user.supportChatPath;
      user.updatedAt = new Date().toISOString();
    }
  }
  return {
    removedChats: beforeChats.length - store.chats.length,
    removedMessages: beforeMessages.length - store.chatMessages.length,
  };
}

async function adminDeleteSupportChatAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminDeleteSupportChatInStore(store, data, auth));
}

function adminDeleteSupportChatInStore(store, data, auth) {
  const chat = findChatByIdOrPath(store, data.chatDocPath || data.supportChatKey);
  if (!chat) {
    return { success: false, code: "CHAT_NOT_FOUND", error: "Чат не найден" };
  }
  const before = publicChatWithUser(store, chat);
  const result = removeSupportChatsFromStore(store, [chat]);
  addAudit(store, auth, "adminDeleteSupportChat", chatPath(chat), before, null, result);
  return {
    success: true,
    code: "SUPPORT_CHAT_DELETED",
    chatPath: chatPath(chat),
    ...result,
  };
}

async function adminClearSupportChatsAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminClearSupportChatsInStore(store, auth));
}

function adminClearSupportChatsInStore(store, auth) {
  const chatsToRemove = [...(store.chats || [])];
  const result = removeSupportChatsFromStore(store, chatsToRemove);
  addAudit(store, auth, "adminClearSupportChats", "chats", {
    chatCount: chatsToRemove.length,
    messageCount: result.removedMessages,
  }, null, result);
  return {
    success: true,
    code: "SUPPORT_CHATS_CLEARED",
    ...result,
  };
}

module.exports = {
  ensureSupportChatAsync,
  getMySupportChatAsync,
  sendSupportChatMessageAsync,
  markSupportChatReadAsync,
  listSupportChatsAsync,
  getSupportChatMessagesAsync,
  adminSendSupportChatMessageAsync,
  adminDeleteSupportChatAsync,
  adminClearSupportChatsAsync,
};
