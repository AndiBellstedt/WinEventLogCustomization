using System;

namespace WELC {
    /// <summary>
    /// 
    /// </summary>
    public class ChannelDefinition {
        /// <summary>
        /// 
        /// </summary>
        public string ProviderName;

        /// <summary>
        /// 
        /// </summary>
        public string ProviderSymbol;

        /// <summary>
        /// 
        /// </summary>
        public string ChannelName;

        /// <summary>
        /// 
        /// </summary>
        public string ChannelSymbol;
    }

    /// <summary>
    /// 
    /// </summary>
    public class ChannelConfig {
        /// <summary>
        /// 
        /// </summary>
        public string ChannelName;

        /// <summary>
        /// 
        /// </summary>
        public string LogFullName;

        /// <summary>
        /// 
        /// </summary>
        public string LogMode;

        /// <summary>
        /// 
        /// </summary>
        public bool Enabled;

        /// <summary>
        /// 
        /// </summary>
        public System.Int64 MaxEventLogSize;
    }


    /// <summary>
    /// 
    /// </summary>
    public class EventLogChannel {
        /// <summary>
        /// 
        /// </summary>
        public string PSComputerName;

        /// <summary>
        /// 
        /// </summary>
        public System.Diagnostics.Eventing.Reader.EventLogConfiguration[] WinEventLog;

        /// <summary>
        /// 
        /// </summary>
        public System.Diagnostics.Eventing.Reader.ProviderMetadata[] Provider;
    }
}
