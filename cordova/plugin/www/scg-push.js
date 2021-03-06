var exec = require('cordova/exec');

var PLUGIN_NAME = "ScgPush";

var ScgPush = {

    start: function(accessToken, appId, callbackUri, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_start", [accessToken, appId, callbackUri]);
    },

    authenticate: function(authToken, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_authenticate", [authToken]);
    },

    getToken: function(success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_getToken", []);
    },

    registerPushToken: function(token, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_registerPushToken", [token]);
    },

    unregisterPushToken: function(token, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_unregisterPushToken", [token]);
    },

    onNotification: function(success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_onnotification", []);
    },

    onTokenRefresh: function(success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_ontokenrefresh", []);
    },

    reportStatus: function(messageID, messageState, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_reportStatus", [messageID, messageState]);
    },

    resolveTrackedLink: function(link, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_resolveTrackedLink", [link]);
    },

    loadAttachment: function(messageId, attachmentId, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_loadAttachment", [messageId, attachmentId]);
    },

    resetBadge: function(token, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_resetBadge", [token]);
    },

    deleteAllInboxMessages: function() {
      exec(null, null, PLUGIN_NAME, "cdv_deleteAllInboxMessages", []);
    },

    deleteInboxMessage: function(messageId, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_deleteInboxMessage", [messageId]);
    },

    deleteInboxMessageAtIndex: function(messageIndex, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_deleteInboxMessageAtIndex", [messageIndex]);
    },

    getAllInboxMessages: function(result) {
      exec(result, null, PLUGIN_NAME, "cdv_getAllInboxMessages", []);
    },

    getInboxMessageAtIndex: function(index, success, failure) {
      exec(success, failure, PLUGIN_NAME, "cdv_getInboxMessageAtIndex", [index]);
    },

    getInboxMessagesCount: function(result) {
      exec(result, null, PLUGIN_NAME, "cdv_getInboxMessagesCount", []);
    }
};

module.exports = ScgPush;
