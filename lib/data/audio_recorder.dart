import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class SparkAudioRecorder {
  SparkAudioRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  Future<String?> start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      return null;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/spark_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    return path;
  }

  Future<String?> stop() async {
    return _recorder.stop();
  }

  Future<void> pause() async {
    await _recorder.pause();
  }

  Future<void> resume() async {
    await _recorder.resume();
  }

  Future<void> cancel() async {
    await _recorder.cancel();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
