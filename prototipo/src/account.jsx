/* Ascesa — Account & security settings */

function SettingRow({ icon, title, value, color, danger, last, onClick, right, sub }) {
  return (
    <div onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 14px', cursor: onClick ? 'pointer' : 'default', borderBottom: last ? 'none' : '1px solid var(--line-soft)' }}>
      {icon && <div style={{ width: 30, height: 30, borderRadius: 9, background: danger ? 'color-mix(in oklch, var(--z6) 16%, transparent)' : 'var(--surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
        <window.Icon name={icon} size={16} color={danger ? 'var(--z6)' : (color || 'var(--text-2)')} />
      </div>}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14.5, fontWeight: 650, color: danger ? 'var(--z6)' : 'var(--text)' }}>{title}</div>
        {sub && <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 1 }}>{sub}</div>}
      </div>
      {right || (value && <span style={{ fontSize: 13, color: 'var(--text-3)', fontWeight: 500 }}>{value}</span>)}
      {onClick && !right && <window.Icon name="chev" size={16} color="var(--text-3)" style={{ marginLeft: 4 }} />}
    </div>
  );
}

function AccountSettingsScreen() {
  const nav = React.useContext(window.NavCtx);
  const [bio, setBio] = React.useState(true);
  const [cloud, setCloud] = React.useState(true);
  const [confirmDelete, setConfirmDelete] = React.useState(false);
  const A = window.ATHLETE;

  const devices = [
    { icon: 'route', name: 'iPhone 15 Pro', detail: 'Questo dispositivo · Milano', now: true },
    { icon: 'watch', name: 'Apple Watch Series 9', detail: 'Attivo 2 min fa' },
    { icon: 'route', name: 'iPad Air', detail: 'Attivo 3 giorni fa' },
  ];

  return (
    <window.Scaffold>
      <window.TopBar title="Account e sicurezza" onBack={() => nav.back()} />
      <div style={{ padding: '4px 16px', display: 'flex', flexDirection: 'column', gap: 18 }}>
        {/* identity */}
        <window.Card pad={16}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <div style={{ width: 52, height: 52, borderRadius: 26, background: 'var(--accent-ink)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
              <span style={{ fontSize: 20, fontWeight: 800, color: 'var(--accent)' }}>MV</span>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 17, fontWeight: 750 }}>{A.name}</div>
              <div style={{ fontSize: 13, color: 'var(--text-3)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>marco.vinci@esempio.it</div>
            </div>
            <span style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11.5, fontWeight: 700, color: 'var(--z3)', background: 'color-mix(in oklch, var(--z3) 14%, transparent)', borderRadius: 999, padding: '5px 9px' }}>
              <window.Icon name="check" size={13} color="var(--z3)" />Verificato
            </span>
          </div>
        </window.Card>

        <div>
          <window.SectionLabel>Accesso</window.SectionLabel>
          <window.Card pad={0}>
            <SettingRow icon="route" title="Email" value="marco.vinci@…" onClick={() => {}} />
            <SettingRow icon="gear" title="Cambia password" onClick={() => {}} />
            <SettingRow icon="check" title="Sblocco con Face ID" sub="Richiedi il volto alla riapertura" right={<window.Toggle on={bio} onChange={setBio} />} last />
          </window.Card>
        </div>

        <div>
          <window.SectionLabel>Dispositivi attivi · {devices.length}</window.SectionLabel>
          <window.Card pad={0}>
            {devices.map((d, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 14px', borderBottom: i === devices.length - 1 ? 'none' : '1px solid var(--line-soft)' }}>
                <div style={{ width: 34, height: 34, borderRadius: 10, background: 'var(--surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
                  <window.Icon name={d.icon} size={17} color={d.now ? 'var(--accent)' : 'var(--text-2)'} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14.5, fontWeight: 650 }}>{d.name}</div>
                  <div style={{ fontSize: 12, color: d.now ? 'var(--z3)' : 'var(--text-3)' }}>{d.detail}</div>
                </div>
                {!d.now && <button style={{ ...window.authTextLink, fontSize: 12.5, color: 'var(--text-2)' }}>Disconnetti</button>}
              </div>
            ))}
          </window.Card>
          <button style={{ width: '100%', marginTop: 10, background: 'transparent', border: '1px solid var(--line)', color: 'var(--text-2)', borderRadius: 13, padding: '12px', fontSize: 13.5, fontWeight: 650, cursor: 'pointer', fontFamily: 'inherit' }}>Esci da tutti i dispositivi</button>
        </div>

        <div>
          <window.SectionLabel>Dati e privacy</window.SectionLabel>
          <window.Card pad={0}>
            <SettingRow icon="bt" title="Sincronizzazione cloud" sub="Hosting UE · ultimo sync 2 min fa" right={<window.Toggle on={cloud} onChange={setCloud} />} />
            <SettingRow icon="gear" title="Gestione consensi" sub="Dati sanitari, email, condivisione" onClick={() => {}} />
            <SettingRow icon="upload" title="Esporta i miei dati" sub="JSON · FIT · CSV (portabilità GDPR)" onClick={() => {}} last />
          </window.Card>
        </div>

        <div>
          <window.SectionLabel>Zona pericolo</window.SectionLabel>
          <window.Card pad={0}>
            <SettingRow icon="back" title="Esci" sub="La sessione resta in cache per l'uso offline" onClick={() => nav.go('auth')} />
            <SettingRow icon="stop" title="Elimina account" danger sub="Cancellazione completa lato server · irreversibile" onClick={() => setConfirmDelete(true)} last />
          </window.Card>
          <div style={{ fontSize: 11.5, color: 'var(--text-3)', padding: '8px 8px 0', lineHeight: 1.45 }}>
            Prima dell'eliminazione ti proponiamo di esportare i dati. La cancellazione rimuove tutto dai nostri server (diritto all'oblio).
          </div>
        </div>
      </div>

      {confirmDelete && (
        <div style={{ position: 'absolute', inset: 0, zIndex: 90, background: 'rgba(12,14,18,0.7)', backdropFilter: 'blur(6px)', display: 'flex', alignItems: 'flex-end' }} onClick={() => setConfirmDelete(false)}>
          <div onClick={e => e.stopPropagation()} style={{ width: '100%', background: 'var(--bg-elev)', borderTopLeftRadius: 26, borderTopRightRadius: 26, border: '1px solid var(--line)', borderBottom: 'none', padding: '24px 22px 34px', display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div style={{ width: 40, height: 4, borderRadius: 2, background: 'var(--line)', alignSelf: 'center' }} />
            <div style={{ width: 52, height: 52, borderRadius: 26, background: 'color-mix(in oklch, var(--z6) 16%, transparent)', display: 'flex', alignItems: 'center', justifyContent: 'center', alignSelf: 'center', marginTop: 4 }}>
              <window.Icon name="stop" size={24} color="var(--z6)" />
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 20, fontWeight: 780 }}>Eliminare l'account?</div>
              <div style={{ fontSize: 13.5, color: 'var(--text-3)', marginTop: 6, lineHeight: 1.5 }}>Tutti i tuoi allenamenti, percorsi e dati verranno cancellati definitivamente. L'operazione non è reversibile.</div>
            </div>
            <button style={{ ...window.authBtnGhost, gap: 8, marginTop: 4 }}><window.Icon name="upload" size={17} />Esporta i dati prima</button>
            <button style={{ width: '100%', background: 'var(--z6)', color: '#fff', border: 'none', borderRadius: 14, padding: '15px', fontSize: 15, fontWeight: 750, cursor: 'pointer', fontFamily: 'inherit' }}>Elimina definitivamente</button>
            <button onClick={() => setConfirmDelete(false)} style={{ ...window.authTextLink, color: 'var(--text-2)', alignSelf: 'center', fontSize: 14 }}>Annulla</button>
          </div>
        </div>
      )}
    </window.Scaffold>
  );
}

window.AccountSettingsScreen = AccountSettingsScreen;
