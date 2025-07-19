using System;
using System.Runtime.InteropServices;

namespace WinUIExample
{
    internal static class Native
    {
        private const string Dll = "bitchat.dll";

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_Initialize();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_Shutdown();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_SendMessage(string text);

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr Bitchat_GetMessagesJSON();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr Bitchat_GetChannelMessagesJSON(string channel);

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr Bitchat_GetPrivateMessagesJSON(string peer);

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_SendPrivateMessage(string peer, string text);

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_StartPrivateChat(string peer);

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_EndPrivateChat();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_JoinChannel(string name);

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_LeaveChannel(string name);

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_SwitchChannel(string name);

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr Bitchat_GetConnectedPeersJSON();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr Bitchat_GetPeerNicknamesJSON();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr Bitchat_GetJoinedChannelsJSON();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr Bitchat_GetPrivateChatPeersJSON();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr Bitchat_GetNickname();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_SetNickname(string name);

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        internal static extern bool Bitchat_IsConnected();

        [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void Bitchat_FreeCString(IntPtr ptr);
    }
}
