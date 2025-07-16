using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Collections.ObjectModel;
using Microsoft.UI.Dispatching;

namespace WinUIExample
{
    public sealed partial class MainWindow : Window
    {
        [DllImport("bitchat.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void Bitchat_SendMessage(string text);

        [DllImport("bitchat.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr Bitchat_GetMessagesJSON();

        [DllImport("bitchat.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void Bitchat_FreeCString(IntPtr ptr);

        [DllImport("bitchat.dll", CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        private static extern bool Bitchat_IsConnected();

        private readonly DispatcherQueueTimer _timer;
        private readonly ObservableCollection<string> _messageItems = new();

        public MainWindow()
        {
            this.InitializeComponent();
            Messages.ItemsSource = _messageItems;

            _timer = DispatcherQueue.CreateTimer();
            _timer.Interval = TimeSpan.FromSeconds(1);
            _timer.Tick += (_, _) => RefreshData();
            _timer.Start();
        }

        private void OnSend(object sender, RoutedEventArgs e)
        {
            Bitchat_SendMessage(MessageBox.Text);
            MessageBox.Text = string.Empty;
        }

        private void RefreshData()
        {
            IntPtr ptr = Bitchat_GetMessagesJSON();
            if (ptr != IntPtr.Zero)
            {
                string json = Marshal.PtrToStringUTF8(ptr) ?? "";
                Bitchat_FreeCString(ptr);
                try
                {
                    var messages = JsonSerializer.Deserialize<List<Message>>(json);
                    if (messages != null)
                    {
                        _messageItems.Clear();
                        foreach (var m in messages)
                        {
                            _messageItems.Add($"{m.sender}: {m.content}");
                        }
                    }
                }
                catch { }
            }

            ConnectionState.Text = Bitchat_IsConnected() ? "Connected" : "Not Connected";
        }

        private class Message
        {
            public string sender { get; set; } = "";
            public string content { get; set; } = "";
        }
    }
}
