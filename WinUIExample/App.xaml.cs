using Microsoft.UI.Xaml;
using System.Runtime.InteropServices;

namespace WinUIExample
{
    public partial class App : Application
    {
        [DllImport("bitchat.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void Bitchat_Initialize();

        [DllImport("bitchat.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void Bitchat_Shutdown();

        public App()
        {
            this.InitializeComponent();
            Bitchat_Initialize();
        }

        protected override void OnExit() {
            Bitchat_Shutdown();
            base.OnExit();
        }
    }
}
