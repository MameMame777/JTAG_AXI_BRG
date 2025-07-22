SVFファイル
SVF（Serial Vector Format）は、ASCII（テキスト）ファイルで、ベンダーに依存しないJTAGテストパターンを表す方法として開発されました。

SVFファイルは、ステートメントやコメントのリストで構成されます。次に例を示します。

SDR 64 TDI(0) TDO(0123456789ABCDEF) MASK(0FFFFFFFFFFFFFFF);
これは、JTAGチェーン内のデバイスのデータレジスタから64ビットをスキャンし、64個のゼロをスキャンして、0FFFFFFFFFFFFFFFのマスクで0x0123456789ABCDEFを読み取ることを期待し、最初の4ビットは重要ではないが残りはすべて重要であることを示します。

ヘッダーとトレーラも設定できるため、各ステップでチェーン内の他のデバイスを考慮する必要なく、JTAGチェーン内の特定のデバイスまたはデバイスのセットをターゲットにできます。

SVFコマンドの完全なリストは次のとおりです。

ENDDR	DRスキャン操作のデフォルトの終了状態を指定
ENDIR	IRスキャン操作のデフォルトの終了状態を指定
FREQUENCY	IEEE 1149.1バス操作の最大テストクロック周波数を指定
HDR	（Header Data Register）後続のDRスキャン操作の先頭に追加されるヘッダーパターンを指定
HIR	（Header Instruction Register）後続のIRスキャン操作の先頭に追加されるヘッダーパターンを指定
PIO	（Parallel Input/Output）並列テストパターンを指定
PIOMAP	（Parallel Input/Output Map）PIO列位置を論理ピンにマップする
RUNTEST	指定されたクロック数または指定された期間、IEEE 1149.1バスを強制的に実行状態にする
SDR	（Scan Data Register）IEEE 1149.1データレジスタスキャンを実行する
SIR	（Scan Instruction Register）IEEE 1149.1命令レジスタスキャンを実行する
STATE	IEEE 1149.1バスを指定された安定状態に強制する
TDR	（Trailer Data Register）後続のDRスキャン操作の最後に追加されるトレーラパターンを指定する
TIR	（Trailer Instruction Register）後続のIRスキャン操作の最後に付加されるトレーラパターンを指定する
TRST	（Test ReSeT）オプションのテストリセット行を制御する