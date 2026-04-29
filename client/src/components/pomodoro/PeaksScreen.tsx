import { TopoMountain } from './Mountain';
import { usePeaks } from '../../hooks/usePeaks';

interface PeaksScreenProps {
  onBack: () => void;
}

export function PeaksScreen({ onBack }: PeaksScreenProps) {
  const [peaks] = usePeaks();
  const totalElev = peaks.reduce((a, b) => a + b.elev, 0);
  const totalSessions = peaks.reduce((a, b) => a + b.sessions, 0);
  const featured = peaks[peaks.length - 1] ?? peaks[0];

  return (
    <div style={{
      width: '100%', height: '100%',
      background: '#F4ECDC',
      color: '#1A1A1A',
      display: 'flex', flexDirection: 'column',
      overflow: 'auto',
    }}>
      <div style={{ padding: '60px 22px 12px' }}>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <button onClick={onBack} style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            fontSize: 24, color: '#1A1A1A', padding: 0,
          }}>←</button>
          <div style={{
            fontFamily: 'ui-monospace, monospace', fontSize: 10, letterSpacing: 1.6,
            opacity: 0.5, textTransform: 'uppercase',
          }}>
            Logbook · Apr 2026
          </div>
          <div style={{ width: 24 }}/>
        </div>
        <div style={{
          fontFamily: 'Georgia, "Iowan Old Style", serif',
          fontSize: 38, fontWeight: 400, letterSpacing: -0.8,
          marginTop: 18, lineHeight: 1,
        }}>
          Summited Peaks
        </div>
        <div style={{
          fontFamily: 'ui-monospace, monospace', fontSize: 11, opacity: 0.55,
          marginTop: 10, display: 'flex', gap: 14, flexWrap: 'wrap',
        }}>
          <span>{peaks.length} summits</span>
          <span>·</span>
          <span>{totalElev.toLocaleString()} m climbed</span>
          <span>·</span>
          <span>{totalSessions} sessions</span>
        </div>
      </div>

      {featured && (
        <div style={{ padding: '14px 22px 0' }}>
          <div style={{
            borderRadius: 22,
            overflow: 'hidden',
            background: '#EAD8C0',
            border: '0.5px solid rgba(0,0,0,0.08)',
            position: 'relative',
            aspectRatio: '16 / 11',
          }}>
            <TopoMountain progress={1} w="100%" h="100%" timeOfDay="dusk" style="topo" accent="#E85D3C"/>
            <div style={{
              position: 'absolute', bottom: 12, left: 14, right: 14,
              display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between',
            }}>
              <div>
                <div style={{
                  fontFamily: 'ui-monospace, monospace', fontSize: 9,
                  opacity: 0.6, letterSpacing: 1.4, textTransform: 'uppercase',
                }}>Latest summit</div>
                <div style={{
                  fontFamily: 'Georgia, serif', fontSize: 22, fontWeight: 400,
                  marginTop: 2,
                }}>{featured.name}</div>
              </div>
              <div style={{
                fontFamily: 'ui-monospace, monospace', fontSize: 11,
                textAlign: 'right', opacity: 0.7,
              }}>
                <div>{featured.elev.toLocaleString()} m</div>
                <div>{featured.date}</div>
              </div>
            </div>
          </div>
        </div>
      )}

      <div style={{
        display: 'grid',
        gridTemplateColumns: '1fr 1fr',
        gap: 12,
        padding: '14px 22px 50px',
      }}>
        {peaks.map((p, i) => (
          <div key={i} style={{
            borderRadius: 14,
            overflow: 'hidden',
            background: '#EAD8C0',
            border: '0.5px solid rgba(0,0,0,0.08)',
            position: 'relative',
            aspectRatio: '4 / 5',
            display: 'flex', flexDirection: 'column',
          }}>
            <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
              <TopoMountain progress={1} w="100%" h="100%" timeOfDay={i % 2 ? 'day' : 'dawn'} style={p.style} accent="#E85D3C"/>
            </div>
            <div style={{
              padding: '8px 10px 10px',
              borderTop: '0.5px dashed rgba(0,0,0,0.15)',
            }}>
              <div style={{
                fontFamily: 'Georgia, serif', fontSize: 13, fontWeight: 500,
                lineHeight: 1.1, letterSpacing: -0.2,
              }}>
                {p.name}
              </div>
              <div style={{
                fontFamily: 'ui-monospace, monospace', fontSize: 9,
                opacity: 0.55, marginTop: 3, display: 'flex', justifyContent: 'space-between',
              }}>
                <span>{p.elev.toLocaleString()}m</span>
                <span>{p.date}</span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
