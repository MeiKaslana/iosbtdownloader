typedef struct {
    float bufferingProgress;
    float totalProgress;
    int downloadSpeed;
    int uploadSpeed;
    int seeds;
    int peers;
    long long total_wanted;
    long long total_wanted_done;
} PTTorrentStatus;
