using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Runtime.InteropServices;

namespace WinUIExample
{
    public sealed partial class MainWindow : Window
    {
        [DllImport("bitchat.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void Bitchat_SendMessage(string text);

        public MainWindow()
        {
            this.InitializeComponent();
        }

        private void OnSend(object sender, RoutedEventArgs e)
        {
            Bitchat_SendMessage(MessageBox.Text);
            MessageBox.Text = string.Empty;
        }
    }
}
