using Microsoft.UI.Xaml;
using System.Runtime.InteropServices;

namespace WinUIExample
{
    public partial class App : Application
    {
        [DllImport("bitchat.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void Bitchat_Initialize();

        public App()
        {
            this.InitializeComponent();
            Bitchat_Initialize();
        }
    }
}
