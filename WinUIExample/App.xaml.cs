using Microsoft.UI.Xaml;

namespace WinUIExample
{
    public partial class App : Application
    {
        public App()
        {
            this.InitializeComponent();
            Native.Bitchat_Initialize();
        }

        protected override void OnExit()
        {
            Native.Bitchat_Shutdown();
            base.OnExit();
        }
    }
}
