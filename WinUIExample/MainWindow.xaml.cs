using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Dispatching;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace WinUIExample
{
    public sealed partial class MainWindow : Window
    {
        private readonly DispatcherQueueTimer _timer;
        private readonly ObservableCollection<string> _publicMessages = new();
        private readonly ObservableCollection<string> _channelMessages = new();
        private readonly ObservableCollection<string> _privateMessages = new();
        private readonly ObservableCollection<string> _channels = new();
        private readonly ObservableCollection<string> _peers = new();

        private string _selectedChannel = string.Empty;
        private string _selectedPeer = string.Empty;

        public MainWindow()
        {
            this.InitializeComponent();
            Messages.ItemsSource = _publicMessages;
            ChannelMessages.ItemsSource = _channelMessages;
            PrivateMessages.ItemsSource = _privateMessages;
            ChannelList.ItemsSource = _channels;
            PeerList.ItemsSource = _peers;

            _timer = DispatcherQueue.CreateTimer();
            _timer.Interval = TimeSpan.FromSeconds(1);
            _timer.Tick += (_, _) => RefreshData();
            _timer.Start();

            LoadNickname();
        }

        private void OnSend(object sender, RoutedEventArgs e)
        {
            Native.Bitchat_SendMessage(MessageBox.Text);
            MessageBox.Text = string.Empty;
        }

        private void OnSendChannelMessage(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrEmpty(_selectedChannel))
            {
                Native.Bitchat_SwitchChannel(_selectedChannel);
                Native.Bitchat_SendMessage(ChannelMessageBox.Text);
                ChannelMessageBox.Text = string.Empty;
            }
        }

        private void OnSendPrivateMessage(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrEmpty(_selectedPeer))
            {
                Native.Bitchat_SendPrivateMessage(_selectedPeer, PrivateMessageBox.Text);
                PrivateMessageBox.Text = string.Empty;
            }
        }

        private void OnJoinChannel(object sender, RoutedEventArgs e)
        {
            var name = JoinChannelBox.Text.Trim();
            if (!string.IsNullOrEmpty(name))
            {
                Native.Bitchat_JoinChannel(name);
                JoinChannelBox.Text = string.Empty;
            }
        }

        private void OnChannelSelected(object sender, SelectionChangedEventArgs e)
        {
            if (ChannelList.SelectedItem is string channel)
            {
                _selectedChannel = channel;
            }
        }

        private void OnPeerSelected(object sender, SelectionChangedEventArgs e)
        {
            if (PeerList.SelectedItem is string peer)
            {
                _selectedPeer = peer;
                Native.Bitchat_StartPrivateChat(peer);
            }
        }

        private void OnSaveNickname(object sender, RoutedEventArgs e)
        {
            Native.Bitchat_SetNickname(NicknameBox.Text.Trim());
        }

        private void LoadNickname()
        {
            IntPtr ptr = Native.Bitchat_GetNickname();
            if (ptr != IntPtr.Zero)
            {
                NicknameBox.Text = Marshal.PtrToStringUTF8(ptr) ?? string.Empty;
                Native.Bitchat_FreeCString(ptr);
            }
        }

        private void RefreshData()
        {
            ConnectionState.Text = Native.Bitchat_IsConnected() ? "Connected" : "Not Connected";
            RefreshPublicMessages();
            RefreshChannelMessages();
            RefreshPrivateMessages();
            RefreshChannels();
            RefreshPeers();
        }

        private void RefreshPublicMessages()
        {
            IntPtr ptr = Native.Bitchat_GetMessagesJSON();
            UpdateMessageList(ptr, _publicMessages);
        }

        private void RefreshChannelMessages()
        {
            if (string.IsNullOrEmpty(_selectedChannel)) return;
            IntPtr ptr = Native.Bitchat_GetChannelMessagesJSON(_selectedChannel);
            UpdateMessageList(ptr, _channelMessages);
        }

        private void RefreshPrivateMessages()
        {
            if (string.IsNullOrEmpty(_selectedPeer)) return;
            IntPtr ptr = Native.Bitchat_GetPrivateMessagesJSON(_selectedPeer);
            UpdateMessageList(ptr, _privateMessages);
        }

        private void RefreshChannels()
        {
            IntPtr ptr = Native.Bitchat_GetJoinedChannelsJSON();
            if (ptr != IntPtr.Zero)
            {
                string json = Marshal.PtrToStringUTF8(ptr) ?? "[]";
                Native.Bitchat_FreeCString(ptr);
                try
                {
                    var arr = JsonSerializer.Deserialize<List<string>>(json);
                    if (arr != null)
                    {
                        _channels.Clear();
                        foreach (var c in arr)
                            _channels.Add(c);
                    }
                }
                catch {}
            }
        }

        private void RefreshPeers()
        {
            IntPtr ptr = Native.Bitchat_GetConnectedPeersJSON();
            if (ptr != IntPtr.Zero)
            {
                string json = Marshal.PtrToStringUTF8(ptr) ?? "[]";
                Native.Bitchat_FreeCString(ptr);
                try
                {
                    var arr = JsonSerializer.Deserialize<List<string>>(json);
                    if (arr != null)
                    {
                        _peers.Clear();
                        foreach (var p in arr)
                            _peers.Add(p);
                    }
                }
                catch {}
            }
        }

        private static void UpdateMessageList(IntPtr ptr, ObservableCollection<string> list)
        {
            if (ptr == IntPtr.Zero) return;
            string json = Marshal.PtrToStringUTF8(ptr) ?? "[]";
            Native.Bitchat_FreeCString(ptr);
            try
            {
                var messages = JsonSerializer.Deserialize<List<Message>>(json);
                if (messages != null)
                {
                    list.Clear();
                    foreach (var m in messages)
                        list.Add($"{m.sender}: {m.content}");
                }
            }
            catch {}
        }

        private class Message
        {
            public string sender { get; set; } = string.Empty;
            public string content { get; set; } = string.Empty;
        }
    }
}
